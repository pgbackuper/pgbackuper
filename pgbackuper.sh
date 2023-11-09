#!/bin/bash
set -eu

BCK_DIRROOT="${1:-/backups}"
PROM_METRIC="${2:-/var/metrics/pg_backuper.prom}"
PROM_VAR_PREFIX="pgbackuper"

function echofatal() { echo "FATAL: $*" 1>&2; exit 1; }
function echoerr() { echo "ERR: $*" 1>&2; }
function echoinfo() { echo "$(date) INFO: $*"; }
function echoprom() { echo "$*" >> "$PROM_METRIC"; }


[ ! -d "${BCK_DIRROOT}" ] && echofatal "Directory for backups(${BCK_DIRROOT}) doesn't exists. Create it or change first parameter."

BCK_DIR="${BCK_DIRROOT}/$(date +%Y%m%d)"

echoinfo "prepare dir for backups(${BCK_DIR})"; 
rm -rf "${BCK_DIR}"; mkdir "${BCK_DIR}";

echoinfo "backuping roles"; 
pg_dumpall --roles-only > "${BCK_DIR}/__roles__"

declare -A ARR_DB_SIZE
declare -A ARR_DB_COMPLETED
declare -A ARR_DB_RUNTIME
while read -r DB; do 
  if [ -n "$DB" ]; then
    echoinfo "backuping DB: $DB";
    DUMPFILE="${BCK_DIR}/${DB}"
    
    START=$(date +"%s.%N");
    pg_dump --schema-only "${DB}" > "${DUMPFILE}.schema"
    pg_dump "${DB}" > "${DUMPFILE}.data"
    RUNTIME=$(echo "$(date +%s.%N) - $START" | bc -l)
    RUNTIME=$(printf "%f" "$RUNTIME")
    ARR_DB_RUNTIME["$DB"]=$RUNTIME

    COMPLETED=0
    COMPLETE_STRING=$(tail -n3 "${DUMPFILE}.data" | head -n1)
    [ "$COMPLETE_STRING" == "-- PostgreSQL database dump complete" ] && COMPLETED=1
    ARR_DB_COMPLETED["$DB"]=$COMPLETED

    SIZE=$(stat -c%s "${DUMPFILE}.data")
    ARR_DB_SIZE["$DB"]=$SIZE

    #printf "db:%20s runtime:%10s size:%10s complete:%s\n" "$DB" "$RUNTIME" "$SIZE" "$COMPLETED"
  fi
done < <(echo "SELECT datname FROM pg_database WHERE datistemplate = false;" | psql --no-password -t)

echoinfo "updating a metrics file($PROM_METRIC)"
TS=$(date +"%s%3N")

: > "$PROM_METRIC"
PROM_VAR="${PROM_VAR_PREFIX}_size"
echoprom "# HELP ${PROM_VAR} backup size in bytes"
echoprom "# TYPE ${PROM_VAR} gauge"
for DB in "${!ARR_DB_SIZE[@]}"; do
  echoprom "${PROM_VAR}{db=\"${DB}\"} ${ARR_DB_SIZE[$DB]} ${TS}"
done
echoprom ""

PROM_VAR="${PROM_VAR_PREFIX}_success"
echoprom "# HELP ${PROM_VAR} is backup valid"
echoprom "# TYPE ${PROM_VAR} gauge"
for DB in "${!ARR_DB_COMPLETED[@]}"; do
  echoprom "${PROM_VAR}{db=\"${DB}\"} ${ARR_DB_COMPLETED[$DB]} ${TS}"
done
echoprom ""

PROM_VAR="${PROM_VAR_PREFIX}_runtime"
echoprom "# HELP ${PROM_VAR} how long did pg_dump take for each db in secs"
echoprom "# TYPE ${PROM_VAR} gauge"
for DB in "${!ARR_DB_RUNTIME[@]}"; do
  echoprom "${PROM_VAR}{db=\"${DB}\"} ${ARR_DB_RUNTIME[$DB]} ${TS}"
done
echoprom ""

echoinfo "done."

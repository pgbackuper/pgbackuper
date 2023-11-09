# pgbackuper

lokalni! zaloha vsech databazi jedne postgresql instance + metriky do promethea


## prereq

- rozebehnuty psql server + instalovany klient - `apt install postresql postregsql-client`
- stat, head, tail - `apt install coreutils`


## instalace

- `pgbackuper.sh` nakopiruj do `/usr/local/bin/` + pridej execute prava
- vytvor adresar pro backupy(def: `/backups`)
- zajisti prava do adresare z metrikama

 
## pouziti

jako defaultni postgresql user(=`postgres` pro debian) spust
`pgbackuper.sh [<cilovy adresar>] [<soubor s prometheus metrikama>]`

defaults:
- <cilovy adresar> - `/backups`
- <soubor s prometheus metrikama> - `/var/metrics/pg_backuper.prom`


## konfigurace cronu

`echo "0 3 * * * postgres /usr/local/bin/pg_backuper.sh > /tmp/pgbackuper.log 2>&1" > /etc/cron.d/pgbackuper`


## omezeni, limity

- zaloha jen lokalni instance
- skript musi bezet pod postresql uzivatelem
- skript neresi retenci zaloh
- max jedna zaloha za den - nova zaloha prepise starou v ramci jednoho dne 


## metriky

pgbackuper_size - velikost jedne zalohy databaze v bytech
pgbackuper_success - je zaloha kompletni (1 = ano, 0 = ne)
pgbackuper_runtime - ja dlouho trvalo zazalohovani jedne DB v sec

## example

```
-rw-r--r-- 1 postgres postgres  608 Nov  8 23:56 __roles__       ............ uzivatele + role
-rw-r--r-- 1 postgres postgres 1135 Nov  8 23:56 tstdb.data      ............ obsah tstdb database
-rw-r--r-- 1 postgres postgres  899 Nov  8 23:56 tstdb.schema    ............ schema tstdb database
...
```

# MySQL Replication Pseudo Post-Hook

This monitors the mysql directory for changes and only parses the active relay-bin for databases being replicated. This will create snapshots of the database and commit the It now supports relay-bin rotation automagically.

## Requirements:
- Install incron via epel
- Set up the following command in incrontab -e as root (at this time)
- mkdir /root/replication/ place BASH script in this directory (or wherever, as it autodetects operating path)
- I personally added this to the $PATH variable so I do not have to run `sh /path/to/sh`, which incron seems to dislike
- Initialized the dump directory to a (preferably private) git repository
- Create a .my.cnf file that is similar to the one provided

## Incrontab Command
``` BASH
/var/lib/mysql/ IN_MODIFY,IN_NO_LOOP /path/to/mysql-listener.sh $@ $# 10
```

### Parameters
- $@ : Passes the file path being monitored to the shell script (which would be /var/lib/mysql/mysqld-relay-bin.xxxxx in the example)
- $# : Passed in the filename itself for identification and filtering
- 10 : Threshold for number of replication events to perform a dump on a database (which is 10 events in this example)

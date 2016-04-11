#!/bin/bash

# Bin Log that the slave operates on
BPATH=${1:-/var/lib/mysql/}
BFILE=$2

# Check to make sure the dump log is valid
if [[ ${BFILE%.*} !=  "mysqld-relay-bin" ]]; then
    exit;
fi

BINLOG="${BPATH}${BFILE}"

# Dump Threshold defaults and assignment
DMPLIMIT=${3:-20}

# Check to make sure the dump log exists
if [ -z $BINLOG ] || [ ! -f $BINLOG ]; then
    echo "Missing Parameter: No mysql-relay-bin log provided! This is needed to track replication!"
    exit 1
fi

# Events to Monitor
declare -a MONITOR=("CREATE TABLE" "ALTER TABLE" "DROP TABLE" "UPDATE" "INSERT" "DELETE")

# Get a little more about ourselves for parsing mysql
ME=$(whoami);
USERHOME=$(getent passwd $ME | awk -F ':' '{print $6}')

# Path to all of the replication stuffs based on where this script operates
REPLICATIONPATH=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
DEBUG="$REPLICATIONPATH/debug.log"

UPPERD=$(date +%s)
BINOUT=$(mysqlbinlog $BINLOG | sed -n "/$UPPERD/,/DELIMITER/p")

DATABASE=$(mysqlbinlog $BINLOG | grep "use \`" | tail -1 | awk -F\` '{print $2}')
# Log used for counting
COUNTLOG=${REPLICATIONPATH}/${DATABASE}.count

# Create count log if it does not exist
if [ ! -f $COUNTLOG ]; then
    echo "1" > $COUNTLOG
fi

# Get number of SQL executions from log and increase by 1
SQLCOUNT=`cat $COUNTLOG`

# See if any of the triggers match what we're watching for
for trigger in "${MONITOR[@]}"
do
    case "$BINOUT" in
        *"$trigger"* )
            echo $((SQLCOUNT + 1)) > $COUNTLOG
            if [ $SQLCOUNT -ge $DMPLIMIT ]; then
		# Check if .my.cnf is set up for current user
		if [! -f /root/.my.cnf]; then
			echo "Missing Dependency: ~/.my.cnf file is needed for credentials! Terminating script."
			exit 1
		fi
		# Requires that a .my.cnf is set up and encapsulates the credentials between comments (ex # Listener Start and # Listener End)
		MYSQLUSER=$(cat ${USERHOME}/.my.cnf | sed -n "/ListenerStart/,/ListenerEnd/p" | grep "user" | awk -F "=" '{print $2}')
		
		# NOTE THE AWK IS LOOKING FOR A DOUBLE QUOTE " AND NOT AN = SIGN!
		MYSQLPWD=$(cat ${USERHOME}/.my.cnf | sed -n "/ListenerStart/,/ListenerEnd/p" | grep "password" | awk -F "\"" '{print $2}')
                # dump database that has exceeded threshold
                mysqldump --user=$MYSQLUSER --password=$MYSQLPWD $DATABASE > ${REPLICATIONPATH}/${DATABASE}.sql

                cd $REPLICATIONPATH
                
                # Git add, commit, and push
                git add .
                git commit -m "Automatic Backup: `date "+%m/%d/%y %T"`"
                git push -u origin master >> $DEBUG
                echo "1" > $COUNTLOG
            fi
            break
        ;;
    esac
done

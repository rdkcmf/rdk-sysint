#!/bin/sh
#watch for rev SSH tunnel termination to terminate stunnel
. /etc/include.properties
. /etc/device.properties

LOG_FILE="$LOG_PATH/stunnel.log"

if [ -f /var/tmp/rssh.pid -a -f /tmp/stunnel.pid ]; then
    REVSSHPID=`cat /var/tmp/rssh.pid`
    STUNNELPID=`cat /tmp/stunnel.pid`
fi

if [ -z "$REVSSHPID" -o -z "$STUNNELPID" ]; then
    if [ ! -z "$STUNNELPID" ]; then
        kill -9 $STUNNELPID
    fi
    exit
fi

echo "Reverse SSH pid: $REVSSHPID, Stunnel pid: $STUNNELPID" >> /opt/logs/stunnel.log

while test -d "/proc/$REVSSHPID"; do
     sleep 5
done

kill -9 $STUNNELPID

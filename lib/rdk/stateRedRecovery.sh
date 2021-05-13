#!/bin/sh

. /etc/include.properties

echo "STATE RED RECOVERY, Initiating recovery software download"
sh $RDK_PATH/deviceInitiatedFWDnld.sh 3 6 >> /opt/logs/swupdate.log 2>&1


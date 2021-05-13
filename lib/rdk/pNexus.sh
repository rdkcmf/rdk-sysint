#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2016 RDK Management, LLC. All rights reserved.
# ============================================================================
#
#ocap-excalibur appears to be creating the proxy-is-up file now
#So don't tail the log, look for the file to exist 

. /etc/device.properties
echo $DEVICE_NAME

nexusFile="/tmp/nexus-is-up"
echo --------- nexus file= $nexusFile
rm $nexusFile

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
DS_PERSISTENT_PATH="/opt/persistent/ds/"
if [ ! -d $DS_PERSISTENT_PATH ]; then
echo "The DS or UI MGR Host Persistent folder is missing"
mkdir -p $DS_PERSISTENT_PATH
fi

while [ 1 ]
do
if [ -f $nexusFile ] ; then
   echo "Nexus is UP"

   if [ "$DEVICE_NAME" = "RNG150" ]; then
     sh /lib/rdk/runIarm.sh >> /opt/logs/uimgr_log.txt &
   else
     /mnt/nfs/env/uimgr_main /opt/uimgr_settings.bin > /opt/logs/uimgr_log.txt &
   fi
   
   touch /tmp/.uiMngrFlag
   exit 0
else
   sleep 1
fi
done
#touch /opt/logs/ocapri_log.txt
#tail -f /opt/logs/ocapri_log.txt | awk '/Tru2way Proxy is ready/ {print "Proxy is up"; exit 0; }'

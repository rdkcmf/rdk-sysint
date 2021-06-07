#!/bin/sh
##############################################################################
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2020 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##############################################################################

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

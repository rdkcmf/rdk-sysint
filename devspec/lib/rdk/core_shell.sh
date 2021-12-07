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

. /etc/include.properties
. /etc/device.properties
. /etc/config.properties

if [ ! -d $CORE_PATH ]; then     
     mkdir -p $CORE_PATH
fi

echo "$1 crash and uploading the cores" >> $LOG_PATH/core_log.txt

if [ "$DEVICE_TYPE" != "mediaclient" ]; then
     if [ "$1" = "mpeos-main" ]; then
          echo 0 > /opt/.uploadMpeosCores
          echo $3_core.prog_$1.signal_$2.gz >> /opt/.mpeos_crashed
          gzip -f >/mnt/memory/corefiles/$3_core.prog_$1.signal_$2.gz
          touch /tmp/.core_dump
          exit 0
     fi
fi

if [ "$IARM_DEPENDENCY_ENABLE" = "false" ]; then
     if [ "$1" = "uimgr_main" ]; then
          gzip -f > /mnt/memory/corefiles/$3_core.prog_$1.signal_$2.gz
          touch /tmp/.core_dump
          exit 0
     fi
fi

case "$1" in 
	"Receiver")
           if [ "$BUILD_TYPE" != "dev" ]; then
                echo "Not writing Receiver core-dump in VBN/PROD"
           else
                gzip -f > /mnt/memory/corefiles/$3_core.prog_$1.signal_$2.gz
                touch /tmp/.core_dump
           fi
           exit 0
           ;;
        "xcal-discovery-")
           gzip -f > /mnt/memory/corefiles/$3_core.prog_$1.signal_$2.gz
           touch /tmp/.core_dump
           ;;
        "xdiscovery")
           gzip -f > /mnt/memory/corefiles/$3_core.prog_$1.signal_$2.gz
           touch /tmp/.core_dump
           ;;
        "tr69agent")
           gzip -f > /mnt/memory/corefiles/$3_core.prog_$1.signal_$2.gz
           touch /tmp/.core_dump
           ;;
        "tr69hostif")
           gzip -f > /mnt/memory/corefiles/$3_core.prog_$1.signal_$2.gz
           touch /tmp/.core_dump
           ;;

         *)
          echo "Dump Created" >> $LOG_PATH/core_log.txt
           gzip -f > /mnt/memory/corefiles/$3_core.prog_$1.signal_$2.gz
           touch /tmp/.core_dump
           ;;
esac

TS=`date +%Y-%m-%d-%H-%M-%S`
#core+mini dumps to Potomac's machine
# Coredump Upload call
if [ "$BUILD_TYPE" = "dev" ]; then
     sh $RDK_PATH/uploadDumps.sh ${TS} 1 &
     sh $RDK_PATH/uploadDumps.sh ${TS} 0 &
else
     sh $RDK_PATH/uploadDumps.sh ${TS} 1 $POTOMAC_SVR &
     sh $RDK_PATH/uploadDumps.sh ${TS} 0 $POTOMAC_SVR &
fi
       


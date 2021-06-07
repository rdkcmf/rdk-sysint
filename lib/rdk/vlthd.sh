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

if [ -f $PERSISTENT_PATH/.sleep ] ; then
   time=`echo $PERSISTENT_PATH/.sleep`
else
   time=$1
fi

VL_THREAD_LOG=vlthreadanalyzer_log.txt

if [ "$DEVICE_TYPE" = "hybrid" ]; then
     VL_THREAD_BIN="/usr/bin/rmfthreadanalyzer ./rmfStreamer"
else
     VL_THREAD_BIN=/mnt/nfs/bin/vlthreadanalyzer
fi
 
loop=1
while [ $loop -eq 1 ]
do
  if [ -f /tmp/.power_on ]; then
       $VL_THREAD_BIN 1 2000 >> $LOG_PATH/$VL_THREAD_LOG
       sleep $time
  else
       $VL_THREAD_BIN 1 2000 >> $TEMP_LOG_PATH/$VL_THREAD_LOG
       sleep 30
  fi
done


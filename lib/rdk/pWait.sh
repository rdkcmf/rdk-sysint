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


. /etc/device.properties

if [ "$DEVICE_TYPE" != "hybrid" ]; then
     proxyPath=`cat /mnt/nfs/env/final.properties | grep OCAP.persistent.root | cut -d "=" -f2`
     echo --------- proxy path= $proxyPath
     #rm $proxyPath/usr/1112/703e/proxy-is-up
     #rm /tmp/stt_received

     while [ 1 ]
     do
        if [ -f $proxyPath/usr/1112/703e/proxy-is-up ] && [ -f /tmp/stt_received ] ; then
	          echo "STT received and Proxy is UP"
	          touch /tmp/.xre-startup
              exit 0
        else
           sleep 1
        fi
     done
else
     touch /tmp/.xre-startup
fi


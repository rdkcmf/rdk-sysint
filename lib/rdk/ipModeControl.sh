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
. /etc/env_setup.sh

loop=1
while [ $loop -eq 1 ]
do
    if [ -f $RAMDISK_PATH/ip_mode_control_shutdown_ipv4 ]; then
         loop=0
         echo "Shutting down the V4 UDHCPC service"
         sh /mnt/nfs/bin/scripts/stop_dhcp_v4.sh $DEFAULT_ESTB_INTERFACE
         ps | grep "udhcpc.*$DEFAULT_ESTB_INTERFACE" | grep -v grep| sed 's/\(^ *\)\([0-9]*\)\(.*\)/\2/g' | xargs kill -9 
         ps | grep udhcpcMon.sh | grep -v grep| awk '{print $1}' | xargs kill -9 
    else
         sleep 3
    fi
done
exit 0

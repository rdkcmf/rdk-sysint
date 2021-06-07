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


MAX_RETRY_COUNT=25
count=0

export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
export MIBS=ALL
export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
export PATH=$PATH:$SNMP_BIN_DIR:
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib

while [ ${count} -le ${MAX_RETRY_COUNT} ]
do
        index=`snmpwalk -m IF-MIB -v 2c -c private localhost 1.3.6.1.2.1.2.2  | grep 236 | cut -d '=' -f1 | cut -d '.' -f2`
        if [[ -z "$index" ]]; then
                sleep 2
        else
                echo $index > /tmp/.mocaIndex.txt
                exit 0
        fi
        count=$((count+1))
done

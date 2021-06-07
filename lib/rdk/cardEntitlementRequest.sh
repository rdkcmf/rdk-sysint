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

sleep 300

# Reading stbip from the getDeviceDetails.sh stdout
if [ -f "$RDK_PATH/getDeviceDetails.sh" ];then
	estbIp=`sh $RDK_PATH/getDeviceDetails.sh read estb_ip`
else
	echo "$RDK_PATH/getDeviceDetails.sh file not found."
fi

LOG_FILE=$LOG_PATH/card_status.log

export MIBS=ALL
export MIBDIRS=/mnt/nfs/bin/target-snmp/share/snmp/mibs:/usr/share/snmp/mibs
export PATH=$PATH:/mnt/nfs/bin/target-snmp/bin:
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib

echo "TIME: `/bin/timestamp`" > $LOG_FILE
echo "ESTB_IP=$estbIp" >> $LOG_FILE

snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
snmpwalk -OQ -v 2c -c "$snmpCommunityVal" 127.0.0.1 SNMPv2-SMI::enterprises.4491.2.3.1.1.4.4.5.1.1.1.5.6   >> $LOG_FILE
sleep 1
snmpwalk -v 2c -c "$snmpCommunityVal" 127.0.0.1 OC-STB-HOST-MIB::ocStbHostCCAppInfoPage >> $LOG_FILE

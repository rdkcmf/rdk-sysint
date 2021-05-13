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

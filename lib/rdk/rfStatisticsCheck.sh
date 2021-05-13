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

. /etc/device.properties

export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
export MIBS=ALL
export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
export PATH=$PATH:$SNMP_BIN_DIR:
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib

LOG_OUTPUT=rf_statistics_log.txt

if [ -f /tmp/.standby ]; then
    LOG_PATH=$TEMP_LOG_PATH
else
    LOG_PATH=/opt/logs
fi

# adding sleep of 180 sec to reduce high load condition during bootup. It is expected, The snmp commands will be executed after the AV is up with this delay.
if [ ! -f /etc/os-release ]; then
    sleep 180
fi

while [ ! -f /tmp/snmpd.conf ]
do
       sleep 15
done

snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
while [ ! "$snmpCommunityVal" ]
do
      sleep 20
      snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
done

while [ "$snmpCommunityVal" = "public" ]
do
   if [ -f /tmp/.standby ]; then
         LOG_PATH=$TEMP_LOG_PATH
   else
         LOG_PATH=/opt/logs
   fi
   echo "Waiting for the Community string for SNMP communication..!" > $LOG_PATH/$LOG_OUTPUT
   sleep 60
   snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
done

echo "Dump the RF Statistics" >> $LOG_PATH/$LOG_OUTPUT

while [ true ]
do
   if [ -f /tmp/.standby ]; then
         LOG_PATH=$TEMP_LOG_PATH
   else
         LOG_PATH=/opt/logs
   fi
   snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
   echo $(date) DownStream Channel Center Freq: $(snmpwalk -OQ -v 2c -c $snmpCommunityVal 192.168.100.1 DOCS-IF-MIB::docsIfDownChannelFrequency.3) >>$LOG_PATH/$LOG_OUTPUT
   echo $(date) DownStream Channel Power: $(snmpwalk -OQ -v 2c -c $snmpCommunityVal 192.168.100.1 DOCS-IF-MIB::docsIfDownChannelPower.3) >>$LOG_PATH/$LOG_OUTPUT 
   echo $(date) DownStream Channel Modn: $(snmpwalk -OQ -v 2c -c $snmpCommunityVal 192.168.100.1 DOCS-IF-MIB::docsIfDownChannelModulation.3) >>$LOG_PATH/$LOG_OUTPUT 
   echo $(date) DownStream Channel Width: $(snmpwalk -OQ -v 2c -c $snmpCommunityVal 192.168.100.1 DOCS-IF-MIB::docsIfDownChannelWidth.3) >>$LOG_PATH/$LOG_OUTPUT 
   echo $(date) UpStream Channel Type: $(snmpwalk -OQ -v 2c -c $snmpCommunityVal 192.168.100.1 DOCS-IF-MIB::docsIfUpChannelType.4) >>$LOG_PATH/$LOG_OUTPUT 
   echo $(date) CM Modulation Type Status: $(snmpwalk -OQ -v 2c -c $snmpCommunityVal 192.168.100.1 DOCS-IF-MIB::docsIfCmStatusModulationType.2) >>$LOG_PATH/$LOG_OUTPUT 
   echo $(date) UpStream Channel Center Freq: $(snmpwalk -OQ -v 2c -c $snmpCommunityVal 192.168.100.1 DOCS-IF-MIB::docsIfUpChannelFrequency.4) >>$LOG_PATH/$LOG_OUTPUT 
   echo $(date) CM Tx Power: $(snmpwalk -OQ -v 2c -c $snmpCommunityVal 192.168.100.1 DOCS-IF-MIB::docsIfCmStatusTxPower.2) >>$LOG_PATH/$LOG_OUTPUT 
   echo $(date) Signal/Noise Ratio: $(snmpwalk -OQ -v 2c -c $snmpCommunityVal 192.168.100.1 DOCS-IF-MIB::docsIfSigQSignalNoise.3) >>$LOG_PATH/$LOG_OUTPUT 
   echo $(date) Modulation Error Ratio: $(snmpwalk -OQ -v 2c -c $snmpCommunityVal 192.168.100.1 DOCS-IF3-MIB::docsIf3SignalQualityExtRxMER.3) >>$LOG_PATH/$LOG_OUTPUT 
   sleep 1800
done

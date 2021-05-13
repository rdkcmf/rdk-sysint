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

snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
setSNMPEnv()
{
     #Set env for SNMP client queries..."
     export MIBS=ALL
     export MIBDIRS=/mnt/nfs/bin/target-snmp/share/snmp/mibs:/usr/share/snmp/mibs
     export PATH=$PATH:/mnt/nfs/bin/target-snmp/bin:
     export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
}  

## get Model No of the box
getModel()
{
    model=`sh $RDK_PATH/getDeviceDetails.sh read model`
    echo $model
}  

getFirmwareVersion()
{
    setSNMPEnv
    ret=`snmpget -OQ -v 2c -c $1 $2 sysDescr.0 | cut -d "=" -f2 | cut -d ":" -f5 | cut -d " " -f2 | cut -d ";" -f1`
     if [[ $? -eq 0 ]] ; then
         echo $ret
     else
         echo ""
     fi
}

getECMMac()
{
    setSNMPEnv
    snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
    ret=`snmpwalk -OQ -v 2c -c "$snmpCommunityVal" 192.168.100.1 -m IF-MIB IF-MIB::ifPhysAddress.2 | cut -d "=" -f2`
     if [[ $? -eq 0 ]] ; then
         echo $ret
     else
         echo ""
     fi
}

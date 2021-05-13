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
. /lib/rdk/utils.sh

cd /mnt/nfs/env

if [ -f $PERSISTENT_PATH/rmfconfig.ini ] && [ "$BUILD_TYPE" != "prod" ] ; then
     export rmfConfigFile=$PERSISTENT_PATH/rmfconfig.ini
else
     export rmfConfigFile=/etc/rmfconfig.ini
fi
if [ -f $PERSISTENT_PATH/debug.ini ] && [ "$BUILD_TYPE" != "prod" ] ; then
     export debugConfigFile=$PERSISTENT_PATH/debug.ini
else
     export debugConfigFile=/etc/debug.ini
fi
ulimit -c unlimited
#once run.sh is used we will move this to run.sh
ulimit -s 128
# Start snmp only after snmpd is running
checkForSnmpd=true
while $checkForSnmpd ;
do
    echo "`timestamp` Waiting for process snmpd before running runSnmp"
    stat=`checkProcess "snmpd"`
    if [ "$stat" != "" ]; then
        echo "`timestamp` snmpd process is running. Starting runSnmp"
        checkForSnmpd=false
    fi
done

export PFC_ROOT=/
#source ../bin/target-snmp/sbin/restart_snmpd.sh
export VL_ECM_RPC_IF_NAME=$DEFAULT_ECM_INTERFACE
export VL_DOCSIS_DHCP_IF_NAME=$UDHCP_INTERFACE
export VL_DOCSIS_WAN_IF_NAME=$ESTB_INTERFACE
export SNMPCONFPATH=/mnt/nfs/bin/target-snmp/sbin

LD_LIBRARY_PATH=/mnt/nfs/bin/:/lib:/usr/local/Qt/lib:/usr/local/lib:/mnt/nfs/lib:/mnt/nfs/bin/target-snmp/lib:$LD_LIBRARY_PATH
GST_PLUGIN_PATH=/lib/gstreamer-0.10:/usr/local/lib/gstreamer-0.10:/mnt/nfs/gstreamer-plugins

if [ "$BUILD_TYPE" != "prod" ] ; then
    LD_LIBRARY_PATH=/opt/hold:$LD_LIBRARY_PATH
fi

export GST_PLUGIN_PATH GST_PLUGIN_SCANNER GST_REGISTRY
export PATH HOME LD_LIBRARY_PATH
rm $PERSISTENT_PATH/.xreisup

# check for device specific setup script and invoke the process
if [ -f /etc/run.sh ]; then
   touch /tmp/.snmpmanager_started
   /etc/run.sh runSnmp --config $rmfConfigFile --debugconfig $debugConfigFile&
else
   touch /tmp/.snmpmanager_started
   runSnmp --config $rmfConfigFile --debugconfig $debugConfigFile &
fi

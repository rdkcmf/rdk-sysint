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

cd /mnt/nfs/env

if [ -f $PERSISTENT_PATH/debug.ini ] && [ "$BUILD_TYPE" != "prod" ] ; then
     export debugConfigFile=$PERSISTENT_PATH/debug.ini
else
     export debugConfigFile=/etc/debug.ini
fi

ulimit -c unlimited
#once run.sh is used we will move this to run.sh
ulimit -s 128

# check for device specific setup script and invoke the process
if [ -f /etc/run.sh ]; then
	touch /tmp/.sdv_started
	/etc/run.sh sdvAgent --debugconfig $debugConfigFile&
else
	export PFC_ROOT=/
	#source ../bin/target-snmp/sbin/restart_snmpd.sh
	export VL_ECM_RPC_IF_NAME=$DEFAULT_ECM_INTERFACE
	export VL_DOCSIS_DHCP_IF_NAME=$UDHCP_INTERFACE
	export VL_DOCSIS_WAN_IF_NAME=$ESTB_INTERFACE

	LD_LIBRARY_PATH=/mnt/nfs/bin/:/opt/hold:/lib:/usr/local/Qt/lib:/usr/local/lib:/mnt/nfs/lib:/mnt/nfs/bin/target-snmp/lib:$LD_LIBRARY_PATH
	GST_PLUGIN_PATH=/lib/gstreamer-0.10:/usr/local/lib/gstreamer-0.10:/mnt/nfs/gstreamer-plugins
	export GST_PLUGIN_PATH GST_PLUGIN_SCANNER GST_REGISTRY
	export PATH HOME LD_LIBRARY_PATH
	touch /tmp/.sdv_started
	sdvAgent --debugconfig $debugConfigFile&
fi

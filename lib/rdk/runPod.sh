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

touch /tmp/ocap_video_is_up

cd /mnt/nfs/env
ulimit -c 51200
#once run.sh is used we will move this to run.sh
ulimit -s 128
rm /opt/.xreisup
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

if [ -e /usr/local/lib/modules/pod*.ko ] ; then
      insmod /usr/local/lib/modules/pod*.ko
      mknod /dev/pod c 38 0
fi

export PFC_ROOT=/
export VL_ECM_RPC_IF_NAME=$DEFAULT_ESTB_INTERFACE
export VL_DOCSIS_DHCP_IF_NAME=$DEFAULT_ESTB_INTERFACE
export VL_DOCSIS_WAN_IF_NAME=$DEFAULT_ESTB_IF

LD_LIBRARY_PATH=/opt/hold:/lib:/usr/local/Qt/lib:/usr/local/lib:/mnt/nfs/lib:/mnt/nfs/bin/target-snmp/lib:$LD_LIBRARY_PATH
GST_PLUGIN_PATH=/lib/gstreamer-0.10:/usr/local/lib/gstreamer-0.10:/mnt/nfs/gstreamer-plugins
export GST_PLUGIN_PATH GST_PLUGIN_SCANNER GST_REGISTRY
export PATH HOME LD_LIBRARY_PATH

# check for device specific setup script and invoke the process
if [ -f /etc/run.sh ]; then
    touch /tmp/.pod_started
   /etc/run.sh runPod --config $rmfConfigFile --debugconfig $debugConfigFile&
else
    touch /tmp/.pod_started
   runPod --config $rmfConfigFile --debugconfig $debugConfigFile&
fi

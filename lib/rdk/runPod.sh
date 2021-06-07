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

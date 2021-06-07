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

export PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/sbin:/usr/local/lighttpd/sbin:/usr/local/sbin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/Qt/lib:/usr/local/lib


enable_function() {
  if [ ! -f /opt/vidiPathEnabled ]; then
    touch  /opt/vidiPathEnabled
    echo "`/bin/timestamp` Vidipath state changed to enabled..Rebooting the box..!" >> /opt/logs/ocapri_log.txt
    sync
  fi
}

disable_function() {
  if [ -f /opt/vidiPathEnabled ]; then
    rm -f /opt/vidiPathEnabled
    echo "`/bin/timestamp` Vidipath state changed to disabled..Rebooting the box..!" >> /opt/logs/ocapri_log.txt
    sync
  fi
}

start_udhcpc_function() {
  if [ -f /opt/vidiPathEnabled ]; then
    /sbin/udhcpc -i ${MOCA_INTERFACE}:0 -s /etc/udhcpc.script &
  fi
}

case "$1" in
  enable)
    enable_function
    ;;
  disable)
    disable_function
    ;;
  start_udhcpc)
    start_udhcpc_function
    ;;
  *)
    echo "Usage: $0 {enable|disable|start_udhcpc}"
    exit 1
  ;;
esac

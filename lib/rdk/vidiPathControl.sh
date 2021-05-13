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

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
USER_ID=0
USER_GROUP=0

if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
     . /lib/rdk/getSecureDumpStatus.sh
fi

if [ -f /etc/os-release ]; then
    exit 0
fi

if [ -d /opt/restricted ]; then
    rm -rf /opt/restricted
fi

if [ -d /tmp ]; then
    chown -R $USER_ID:$USER_GROUP /tmp
fi

if [ -d /dev ]; then
    chown -Rh $USER_ID:$USER_GROUP /dev
fi

if [ -d /var/logs ]; then
    chown -R $USER_ID:$USER_GROUP /var/logs
fi

if [ -f /opt/logs/receiver.log ]; then
   chown $USER_ID:$USER_GROUP /opt/logs/receiver.log
fi

chown $USER_ID:$USER_GROUP /dev/fusion*
chown $USER_ID:$USER_GROUP /tmp/fusion.*
chown $USER_ID:$USER_GROUP /opt/xupnp/
chown -R $USER_ID:$USER_GROUP /opt
chown $USER_ID:$USER_GROUP $CORE_PATH
chown $USER_ID:$USER_GROUP $MINIDUMPS_PATH
chown $USER_ID:$USER_GROUP /dev/avcap_core
chown $USER_ID:$USER_GROUP /var/logs/pipe_receiver
chown $USER_ID:$USER_GROUP /tmp/csmedia_msr*
chown $USER_ID:$USER_GROUP /tmp/video1_msr*
chown $USER_ID:$USER_GROUP /version.txt
chown $USER_ID:$USER_GROUP /SetEnv.sh
                                           

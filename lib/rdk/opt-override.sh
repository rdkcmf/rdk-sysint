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

if [ -f /opt/rmfconfig.ini ]  && [ "$BUILD_TYPE" != "prod" ]; then
   RMFCONFIGINIFILE=/opt/rmfconfig.ini
else
   RMFCONFIGINIFILE=/etc/rmfconfig.ini
fi

if [ -f /opt/debug.ini ]  && [ "$BUILD_TYPE" != "prod" ]; then
   DEBUGINIFILE=/opt/debug.ini
else
   DEBUGINIFILE=/etc/debug.ini
fi

if [ -f /opt/netsrvmgr.conf ]  && [ "$BUILD_TYPE" != "prod" ]; then
   NETSRVMGRINIFILE=/opt/netsrvmgr.conf
else
   NETSRVMGRINIFILE=/etc/netsrvmgr.conf
fi

if [ -f /opt/notify_webpa_cfg.json ]  && [ "$BUILD_TYPE" != "prod" ]; then
   WEBPANOTIFYINCFG=/opt/notify_webpa_cfg.json
else
   WEBPANOTIFYINCFG=/etc/notify_webpa_cfg.json
fi

/bin/systemctl set-environment RMFCONFIGINIFILE=$RMFCONFIGINIFILE
/bin/systemctl set-environment DEBUGINIFILE=$DEBUGINIFILE
/bin/systemctl set-environment NETSRVMGRINIFILE=$NETSRVMGRINIFILE
/bin/systemctl set-environment WEBPANOTIFYINCFG=$WEBPANOTIFYINCFG

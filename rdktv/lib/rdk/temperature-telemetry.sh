#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2021 RDK Management, LLC. All rights reserved.
# ============================================================================

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi
boardTemp=`/bin/cat /sys/class/thermal/thermal_zone0/temp | sed 's/./&./2'`c

/bin/echo Temperature:$boardTemp
t2ValNotify "Board_temperature_split" "$boardTemp"

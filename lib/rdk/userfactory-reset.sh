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

if [ -d /opt/tts/nuance/languages ]; then
    find /opt/tts/nuance/languages -mindepth 1 -maxdepth 1 ! -name 'enu' ! -name 'common' -exec rm -rf {} \;
fi

sh /lib/rdk/warehouse-reset.sh

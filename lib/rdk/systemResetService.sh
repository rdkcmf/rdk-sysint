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

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib

if [ -f /SetEnv.sh ]; then
    source /SetEnv.sh
fi
# Checking the dependency module before startup
nice sh $RDK_PATH/iarm-dependency-checker "RESET"

if [ -f /Reset ]; then
     /Reset > $TEMP_LOG_PATH/Reset.txt &
fi


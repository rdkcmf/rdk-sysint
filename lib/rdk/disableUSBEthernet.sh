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

if [ -f /etc/device.properties ];then
    . /etc/device.properties
fi
build=`echo $BUILD_TYPE | tr '[:upper:]' '[:lower:]'`
if [ "$build" = "prod" ];then
    echo "TRUE"
else
    echo "FALSE"
fi

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

if [ -f /tmp/date_completed ];then
     echo "BUILD TIME is already set previously..!"
     exit 0
fi
buildTime=`grep BUILD_TIME /version.txt | cut -d "=" -f2|sed -e 's/\"//g'`
if [ "$buildTime" ];then
     echo "Default Time Setup: $buildTime"
     date -s "$buildTime"
else
     date -s 2001.01.01-00:00:00
fi

touch /tmp/date_completed
exit 0

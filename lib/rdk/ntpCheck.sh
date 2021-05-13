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

echo "Calling the ntpclient script"
if [ ! -f /opt/persistent/firstNtpTime ]; then
        echo "factory fresh box creating first ntp time"
        echo `date` > /opt/persistent/firstNtpTime
fi
if [ ! -f /tmp/timeReceivedNTP ]; then
        echo " ntp time received "
        echo `date` > /tmp/timeReceivedNTP
fi


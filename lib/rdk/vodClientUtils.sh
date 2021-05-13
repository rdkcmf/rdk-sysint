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
if [ -f /tmp/vodClientExited ]; then
   # Sleep for enabling restart of vodClientApp to complete initialization
   sleep 2
   echo -n "VOD_CRASHED" > /tmp/vod_crash_monpipe &
   rm -f /tmp/vodClientExited
fi


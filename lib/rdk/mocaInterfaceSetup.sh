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

#==================================================================
# SCRIPT: mocaInterface.sh
# USAGE : mocaInterface.sh <interface name)
# DESCRIPTION: script to enable/disable moca interface for lightsleep
#==================================================================
interface=$1
flag=$2

if [ $flag -eq 1 ] ; then
     sh /lib/rdk/mocaSetup.sh 0 eth0 
else
     /etc/moca/net.moca stop
fi

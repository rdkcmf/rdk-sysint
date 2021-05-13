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

#MoCA 2.0 supports mocap
if [ -f /usr/bin/mocap ]; then
  linkStatus=`mocap get --link | awk '{for (i=1;i<=NF;i++) if($i ~/link_status/) print $(i+2)}' |tr '[A-Z]' '[a-z]'`
else
  linkStatus=`mocactl show --status | grep linkStatus | sed 's/.*linkStatus.*:/\1/' | tr -d ' ' | tr '[A-Z]' '[a-z]'`
fi

#echo $linkStatus

if [ "$linkStatus" == "up" ]; then
  echo 1
else
  echo 0
fi


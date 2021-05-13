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
# Script to restore the power state before reboot 
# Please refer to PARKER-4473 for details
# first check if the config flag is set
flag=`cat /mnt/nfs/env/mpeenv.ini | grep "SAVE_POWERSTATE_ON_REBOOT" | cut -d "=" -f2`
#restore the power state if flag is TRUE; do nothing otherwise
if [ $flag == "TRUE" ]; then
  # check if the file existis
  if [ -f /opt/lastPowerState ] ; then
        str=`cat /opt/lastPowerState`
        echo $str
        /SetPowerState $str
        ret=`rm /opt/lastPowerState`
  fi
fi


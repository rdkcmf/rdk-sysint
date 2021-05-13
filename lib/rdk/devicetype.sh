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
. /etc/device.properties
. $RDK_PATH/utils.sh
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib/

if [ "$DEVICE_TYPE" != "mediaclient" ]; then
      . $RDK_PATH/snmpUtils.sh

      #ENV for the SNMP queries to the box
      setSNMPEnv
      max_count=120
      counter=0
      while [ $counter -lt 120 ]
      do
         snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
         #get current model using SNMP request
         current_model=`getModel`
         result=`echo $current_model | grep $MODEL_NUM`
         if [ $? -ne 0 ]; then
	     sleep 1
             counter=$(( $counter + 1 ))
         else
             counter=$max_count
         fi
      done
      #model using SNMP request
      echo $current_model
else
      getModel
fi


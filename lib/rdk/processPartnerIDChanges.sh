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

. /etc/include.properties
. /etc/device.properties

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
export PATH=$PATH:/usr/local/bin
if [ ! -f /etc/os-release ]; then
	IARM_EVENT_BINARY_LOCATION=/usr/local/bin
else
	IARM_EVENT_BINARY_LOCATION=/usr/bin
fi

eventManager()
{
   if [ -f $IARM_EVENT_BINARY_LOCATION/IARM_event_sender ]; then
          $IARM_EVENT_BINARY_LOCATION/IARM_event_sender PartnerIdEvent 0
   else
          echo "Missing the binary $IARM_EVENT_BINARY_LOCATION/IARM_event_sender"
   fi
}

# restart WebPA client to pick up new partner id
systemctl restart parodus &

if [ $# -ne 1 ]
then
  echo "Usage: processPartnerIDChanges.sh <partner_id>"
  exit 1
fi

if [ "$DEVICE_TYPE" = "mediaclient" ];then
    if [ -f "$RDK_PATH/clearACSConf.sh" ];then
        sh $RDK_PATH/clearACSConf.sh $1
    else
        echo "$RDK_PATH/clearACSConf.sh file not found."
    fi
else
	eventManager
fi

# Check and restart SDV Agent
if [ -f "$RDK_PATH/runSdvAgent.sh" ];then
    pidof "sdvAgent"
    if [ $? -eq 0 ]; then
         if [ ! -f /etc/os-release ]; then
              /etc/init.d/sdv-service stop
         else
              killall "sdvAgent"
         fi
    fi
    echo "ParnerID changed..! Restarting SDV Agent..!"
    if [ ! -f /etc/os-release ]; then
          /etc/init.d/sdv-service restart
    else
          sh $RDK_PATH/runSdvAgent.sh &
    fi
else
    echo "$RDK_PATH/runSdvAgent.sh file not found."
fi

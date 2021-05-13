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

. /etc/device.properties
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/lib:/usr/local/lib

DS_PERSISTENT_PATH="$APP_PERSISTENT_PATH/ds/" 

cd /usr/local/bin

if [ "$BOX_TYPE" = "XG1" ]; then
    ./hostData_to_2_0 $APP_PERSISTENT_PATH/hostData1 $DS_PERSISTENT_PATH/hostData

	
	if [ -d /tmp/mnt/diska3/persistent/usr/1112/703e/parker/parker.properties-zoom[D] ]; then

	   	if [ -f /tmp/mnt/diska3/persistent/usr/1112/703e/parker/parker.properties-zoom[D]/Zoom\ Mode=1 ];  then
      		 echo "MIgration SCript : VideoDevice.DFC is None"
       		 echo "VideoDevice.DFC None" >>  /tmp/mnt/diska3/persistent/ds/hostData
   		fi
              
  	 	if [ -f /tmp/mnt/diska3/persistent/usr/1112/703e/parker/parker.properties-zoom[D]/Zoom\ Mode=8 ];  then
      		 echo "Migration Script : VideoDevice.DFC is Full"
       		 echo "VideoDevice.DFC Full" >>  /tmp/mnt/diska3/persistent/ds/hostData
  	 	fi
   
  		 rm -rf /tmp/mnt/diska3/persistent/usr/1112/703e/parker/parker.properties-zoom[D]
  	fi
fi 

#!/bin/sh
##############################################################################
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2020 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##############################################################################


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

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


. /etc/include.properties
. /etc/device.properties
. /etc/env_setup.sh

log=$1
pipe=$2

if [ -f /etc/os-release ]; then 
    exit 0
fi

LOG_FILE="$LOG_PATH/$log"                                                            
if [ "$LIGHTSLEEP_ENABLE" = "true" ]; then                                                   
     LOG_PIPE="$TEMP_LOG_PATH/$pipe"                                             
     stat=`find $TEMP_LOG_PATH -name $pipe -type f`                              
     if [ "$stat" ]; then                                                            
           cat $LOG_PIPE >> $LOG_FILE                                                         
           echo "$LOG_PIPE is not a pipe" >> $LOG_PATH/lightsleep.log                        
           rm -rf $LOG_PIPE                                                                
     fi           
     mkfifo $LOG_PIPE &> /dev/null                                                         
     # Checking the logging pipe before startup                                                       
     ret=`ps | grep $LOG_PIPE | grep -v grep`                                                                   
     if [ ! "$ret" ]; then                                                                                     
           cat $LOG_PIPE >> $LOG_FILE &       
     fi                                                                                                             
fi 

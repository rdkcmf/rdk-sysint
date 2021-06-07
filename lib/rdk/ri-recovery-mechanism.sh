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

. /etc/env_setup.sh
. /lib/rdk/utils.sh


LOG_FILE=/opt/logs/ocapri_log.txt

bootUpCheck()
{
  num=0
  if [ ! -f /tmp/.ri-reboot-count ]; then
       echo $num > /tmp/.ri-reboot-count
  else
       num=`cat /tmp/.ri-reboot-count`
       if [ $num -ge 3 ]; then
           echo "Rebooting the box due to RI startup issue..!" >> $LOG_FILE
           sh /rebootNow.sh -s RI_Recovery -o "Rebooting the box due to RI startup issue..."
       else
           num=`expr $num + 1`
           echo $num > /tmp/.ri-reboot-count
       fi
  fi
}

riServiceRestart()
{
    rm -rf /tmp/ri-recovery-flag1 &> /dev/null                         
    rm -rf /tmp/ri-recovery-flag2 &> /dev/null            
    rm -rf /tmp/ri-recovery-flag3 &> /dev/null                     
    # check for retry count
    bootUpCheck
    echo -n `cat /tmp/.ri-reboot-count`
    echo ". Restarting the RI service due to bootup issue..!" >> $LOG_FILE
    /etc/init.d/ri-service restart                               
    exit 0                                                
}

sleep 25 
# runRI, runri & mpeos is not running
if [ ! -f /tmp/ri-recovery-flag1 ]; then
     sleep 10
     stat=`checkProcess "runRI"`                                                
     if [ "$stat" = "" ]; then                                                  
           stat=`checkProcess "runri"`                                           
           if [ "$stat" = "" ]; then
               stat=`checkProcess "mpeos-main"`                                 
               if [ "$stat" = "" ]; then
                    riServiceRestart
               fi
           fi
     fi
     echo "$(date) Bootup Issue: RI Service not started yet..!" >> $LOG_FILE
else
     echo "RI Service is UP..!" >> $LOG_FILE
fi

sleep 20
# runRI is running & runri.sh & mpeos are not running
if [ ! -f /tmp/ri-recovery-flag2 ]; then
     stat=`checkProcess "runri"`                                           
     if [ "$stat" = "" ]; then
          stat=`checkProcess "mpeos-main"`                                 
          if [ "$stat" = "" ]; then
                riServiceRestart
          fi
     fi 
     echo "$(date) Bootup issue in RI script: ri-service..!" >> $LOG_FILE
else
   echo "RI Script is UP..!" >> $LOG_FILE
fi

sleep 10
# runRI & runri.sh are running & mpeos is not running
if [ ! -f /tmp/ri-recovery-flag3 ]; then
     stat=`checkProcess "mpeos-main"`
     if [ "$stat" = "" ]; then
           riServiceRestart
     fi
 
     echo "$(date) Bootup issue in RI module script: ri-service..!"  >> $LOG_FILE
else
      echo "mpeos-main is up & running..!" >> $LOG_FILE
fi


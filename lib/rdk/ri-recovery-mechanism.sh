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


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
. /etc/env_setup.sh

if [ "$LIGHTSLEEP_ENABLE" != "true" ] ; then exit; fi

RamDiskBase="$TEMP_LOG_PATH"
FILE="lightsleep.log"
LOGFILE=/opt/logs/lightsleep.log

# look for configuration file overrides
daemonConfigFile="/etc/lightsleep.conf"
if [ -f "/opt/lightsleep.conf" ] ; then
    daemonConfigFile=/opt/lightsleep.conf
fi

# retrieve/compute initial configuration - log the information to the log file
PowerOnCheckInterval=`grep "PowerOnCheckInterval" $daemonConfigFile | cut -d '=' -f2`
StandbyCheckInterval=`grep "StandbyCheckInterval" $daemonConfigFile | cut -d '=' -f2`
UsageThreshold=`grep "UsageThreshold" $daemonConfigFile | cut -d '=' -f2`
forceCheckInterval=120
checkcount=`expr $StandbyCheckInterval / $forceCheckInterval`

echo "checkcount = $checkcount" >> $LOGFILE                          
echo "StandbyCheckInterval = $StandbyCheckInterval" >> $LOGFILE      
echo "PowerOnCheckInterval= $PowerOnCheckInterval" >> $LOGFILE       
echo "UsageThreshold = $UsageThreshold" >> $LOGFILE                  

syncLog()
{
    cWD=`pwd`
    syncPath=`find $TEMP_LOG_PATH -type l -exec ls -l {} \; | cut -d ">" -f2| tr -d ' '`
    if [ "$syncPath" != "$LOG_PATH" ] && [ -d "$TEMP_LOG_PATH" ]; then
         cd "$TEMP_LOG_PATH"
         for file in `ls *.txt *.log`
         do
            cat $file >> $LOG_PATH/$file
            cat /dev/null > $file
         done
         cd $cWD
    else
         echo "Sync Not needed, Same log folder"
    fi
}

getHDState()
{
	hdparm -C /dev/sda | grep standby 
	if [ $? -ne 0 ]; then
		echo 'poweron'
	else
		echo 'standby'
	fi    
}

# Let MAF to get initialized
#sleep 10

hdstate=`getHDState`
echo hdstate: $hdstate >> $TEMP_LOG_PATH/lightsleep.log
echo `/bin/timestamp` Disk power state is $hdstate >> ${RamDiskBase}/$FILE
lasthddstate=$hdstate

# Checking the dependency module before startup
nice sh $RDK_PATH/iarm-dependency-checker "LIGHTSLEEP"
sleep 60

while [ 1 ]                                                                          
do                                                                                   
        #Note: Check if the box is in standby mode or not                            
        check=0                                                                      
        counter=0                                                                    
        touch /tmp/.lightsleep
        while [ $check -eq 0 ]                                                       
        do                                                                           
                # source /SetEnv.sh                                                    
                # MAF_StackSimuApp -s /tmp/maf.txt | grep "Current Power State" | grep "Stand By" >> $LOGFILE
                echo `/bin/timestamp` >> $LOGFILE                        
                /QueryPowerState -c &> /tmp/output.txt                              
                cat /tmp/output.txt | grep "STANDBY" >> $LOGFILE
                if [ $? -eq 0 ]                                                                                            
                then                       
                        rm -rf /tmp/.power_on 
                        LOGFILE=$TEMP_LOG_PATH/lightsleep.log                                                                               
                        if [ ! -f /tmp/.standby ] ; then                                                         
			                 echo "`/bin/timestamp` LIGHTSLEEP Standby Init" >> $LOGFILE
                             ret=`ps | grep cat | grep "$TEMP_LOG_PATH/pipe" | head -n 1 |awk '{print $1}'`
                             if [ "$ret" = "root" ];then
                                 ps | grep cat | grep "$TEMP_LOG_PATH/pipe" | awk '{print $2}' > /tmp/processIDs
                             else
                                 ps | grep cat | grep "$TEMP_LOG_PATH/pipe" | awk '{print $1}' > /tmp/processIDs
                             fi
                             if [ -f /tmp/.lightsleep ];then rm -rf /tmp/.lightsleep; fi
                             hdstate=`getHDState`                                                                        
                             lasthddstate=$hdstate                                                                       
                             echo `/bin/timestamp` LIGHTSLEEP standby: Setting spin down duration to 90 seconds >> $LOGFILE
                             hdparm -S 18 /dev/sda                                                                                     
                             touch /tmp/.standby
                        fi                                                                                                               
                        $RDK_PATH/lightsleepCopy.sh 0
                        sleep $forceCheckInterval                                                                                        
                        counter=`expr $counter + 1`                                                                                      
                        if [ $counter -eq $checkcount ]                                                                                  
                        then                                                                                                             
                                check=1                                                                                                  
                        fi                                                                                                               
                else          
                        LOGFILE=/opt/logs/lightsleep.log                   
                        rm -rf /tmp/.standby
                        if [ ! -f /tmp/.power_on ] ; then                                                                       
			                  echo "`/bin/timestamp` LIGHTSLEEP Power On Init" >> $LOGFILE
                              ret=`ps | grep cat | grep "$TEMP_LOG_PATH/pipe" | head -n 1 |awk '{print $1}'`
                              if [ "$ret" = "root" ];then
                                   ps | grep cat | grep "$TEMP_LOG_PATH/pipe" | awk '{print $2}' > /tmp/processIDs
                              else
                                   ps | grep cat | grep "$TEMP_LOG_PATH/pipe" | awk '{print $1}' > /tmp/processIDs
                              fi
                              hdstate=`getHDState`                                                                                       
                              lasthddstate=$hdstate                                                                                      
                              echo `/bin/timestamp` LIGHTSLEEP poweron: Setting spin down duration to 0 seconds >> $LOGFILE  
                              hdparm -S 0 /dev/sda
                              touch /tmp/.power_on
                        fi                                                                                                               
                        $RDK_PATH/lightsleepCopy.sh 1
                        sleep 60                                                                                                         
                        check=1
                fi                                                                                                                       
                                                                                                                                         
                if [ "$hdstate" == "standby" ]; then                                                                                     
                       TSIZE=`df | grep -w $RAM_PATH | grep -v disk | tr -s " " | cut -d " " -f3`                                                                
                       if [ $TSIZE -gt $UsageThreshold ]; then                                                                           
                            echo "Threshold reached, syncing ramdisk and harddisk" >> ${RamDiskBase}/$FILE                               
                            check=1                                                                                                      
                       fi                                                                                                                
                fi                                                                                                                       
        done                                                                                                                             
                                                                                                                                         
        syncLog                                                                                                                          
done 

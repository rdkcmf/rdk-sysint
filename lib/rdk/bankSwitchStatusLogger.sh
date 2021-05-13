# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2016 RDK Management, LLC. All rights reserved.
# ============================================================================
. /etc/device.properties
. /etc/include.properties

BANK_SWITCH_STATUS_FILE="/opt/bank_switch_status.txt"
CDL_FLASHED_FILE_NAME="/opt/cdl_flashed_file_name"
FW_DNLD_STATUS_FILE="/opt/fwdnldstatus.txt"

LogFile=$LOG_PATH/bank_switch.log

getActiveBank(){
    activeBank=`cat /proc/cmdline | sed -e "s/.*root=//g" | cut -d ' ' -f1`
    echo $activeBank
}

getPrevActiveBank(){
    prevActiveBank=""
    if [ -f $BANK_SWITCH_STATUS_FILE ]; then
        prevActiveBank=`cat $BANK_SWITCH_STATUS_FILE | grep 'Current Active Bank' | cut -d '|' -f2`
    fi
    echo $prevActiveBank
}

updateCurrentActiveBank(){
    currentActiveBank=$1
    if [ -f $BANK_SWITCH_STATUS_FILE ]; then
       sed -i "s#Current Active Bank.*#Current Active Bank|$1#g" $BANK_SWITCH_STATUS_FILE
    fi
}

incrementTotalBankSwitchCount(){
     # Get value from status file and increment by 1
     totalBankSwitchCount=`cat $BANK_SWITCH_STATUS_FILE | grep "Total Bank switches" | cut -d "|" -f2`
     totalBankSwitchCount=`expr $totalBankSwitchCount + 1`
     sed -i "s/Total Bank switches.*/Total Bank switches|$totalBankSwitchCount/g" $BANK_SWITCH_STATUS_FILE

}

incrementUnintendedBankSwitchCount(){
     # Get value from status file and increment by 1
     totalUnintendedCount=`cat $BANK_SWITCH_STATUS_FILE | grep "No of unitentional switches" | cut -d "|" -f2`
     totalUnintendedCount=`expr $totalUnintendedCount + 1`
     sed -i "s/No of unitentional switches.*/No of unitentional switches|$totalUnintendedCount/g" $BANK_SWITCH_STATUS_FILE
}

updateBankSwitchReasonAndTime(){
     reasonForUpgrade=$1
     timeStamp=`timestamp | cut -d ' ' -f1`
     sed -i "s/Reason for last switch.*/Reason for last switch|$reasonForUpgrade/g" $BANK_SWITCH_STATUS_FILE
     sed -i "s/Timestamp of last switch.*/Timestamp of last switch|$timeStamp/g" $BANK_SWITCH_STATUS_FILE

}

updateLastUpdateTime() {
     timeStamp=`timestamp | cut -d ' ' -f1`
     sed -i "s/Last Updated Time Stamp.*/Last Updated Time Stamp|$timeStamp/g" $BANK_SWITCH_STATUS_FILE
}

getFWVersion()
{
   verStr=`cat /version.txt | grep ^imagename:$FW_VERSION_TAG1`
   if [ $? -eq 0 ]
   then
       echo $verStr | cut -d ":" -f 2
   else
       cat /version.txt | grep ^imagename:$FW_VERSION_TAG2 | cut -d ":" -f 2
   fi
}


## main app

# Wait until system clock is set.
while [ ! -f /tmp/stt_received ] && [ ! -f /tmp/timeReceivedNTP ]
do
    sleep 1
done

# Update Previous reboot reason once STT is accuried
/bin/sh /lib/rdk/updatePreviousRebootInfo.sh &

activeBank=$(getActiveBank)
echo "`timestamp` activeBank : $activeBank" >> $LogFile

if [ -f $BANK_SWITCH_STATUS_FILE ]; then
   echo "`timestamp` Bank switch status file present" >> $LogFile
   previousBank=$(getPrevActiveBank)
   echo "`timestamp` previousBank : $previousBank" >> $LogFile

   if [ "$activeBank" != "$previousBank" ]; then
       echo "`timestamp` Current active bank and previous active banks are different" >> $LogFile
       echo "`timestamp` Updating the total bankswitch counters " >> $LogFile
       incrementTotalBankSwitchCount
       lastFlashedFileName=`cat $CDL_FLASHED_FILE_NAME`
       currFWVersion=$(getFWVersion)
       echo "`timestamp` lastFlashedFileName = $lastFlashedFileName" >> $LogFile
       echo "`timestamp` currFWVersion = $currFWVersion" >> $LogFile
       reasonForUpgrade=""
       echo $lastFlashedFileName | grep -i "$currFWVersion" >> /dev/null
       if [ $? -ne 0 ]; then
           echo "`timestamp` Current version is different from last flashed file. Uintentional bank switch" >> $LogFile
           incrementUnintendedBankSwitchCount
           reasonForUpgrade="Unintended"
       else
           reasonForUpgrade=`cat $FW_DNLD_STATUS_FILE | grep Proto | cut -d "|" -f2`
           reasonForUpgrade="$reasonForUpgrade Upgrade"
           echo "`timestamp` Boot up after normal upgrade. Mode of upgrade is $reasonForUpgrade" >> $LogFile
       fi
       updateCurrentActiveBank $activeBank
       updateBankSwitchReasonAndTime $reasonForUpgrade
   else
       echo "`timestamp` Current active bank and previous active banks are same. No bank switch during bootup" >> $LogFile
   fi
   updateLastUpdateTime
else
    # Create initial file with all details and counter values set to 0
    echo "`timestamp` Creating initial bank switch status file" >> $LogFile
    touch $BANK_SWITCH_STATUS_FILE
    monitoringStartDate=`timestamp | cut -d ' ' -f1`
    lastUpdated=$monitoringStartDate
    reasonForUpgrade=`cat $FW_DNLD_STATUS_FILE | grep Proto | cut -d "|" -f2`
    # Updating the status for the first time
    echo "Start Date of monitoring|$monitoringStartDate" > $BANK_SWITCH_STATUS_FILE
    echo "Current Active Bank|$activeBank" >> $BANK_SWITCH_STATUS_FILE
    echo "Total Bank switches|0" >> $BANK_SWITCH_STATUS_FILE
    echo "No of unitentional switches|0" >> $BANK_SWITCH_STATUS_FILE
    echo "Timestamp of last switch|$monitoringStartDate" >> $BANK_SWITCH_STATUS_FILE
    echo "Reason for last switch|$reasonForUpgrade" >> $BANK_SWITCH_STATUS_FILE
    echo "Last Updated Time Stamp|$monitoringStartDate" >> $BANK_SWITCH_STATUS_FILE

fi

echo " " >> $LogFile

# Displaying the results to update applications.log during service startup
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Bank Switch Status~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
cat $BANK_SWITCH_STATUS_FILE
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

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

##################################################################
## Script to do Device Initiated Firmware Download
## Once box gets IP, check for DCMSettings.conf
## If DCMSettings.conf file is present schedule a cron job using schedule time from conf file
## Invoke deviceInitiated with no retries in this case
## If DCMSettings.conf is not present, Invoke DeviceInitiated with retry (1hr)
##################################################################

. /etc/include.properties
. /etc/device.properties

IARM_EVENT_BINARY_LOCATION=/usr/bin
if [ ! -f /etc/os-release ]; then
    IARM_EVENT_BINARY_LOCATION=/usr/local/bin
fi

if [ "$DEVICE_TYPE" != "mediaclient" ]; then
   . $RDK_PATH/commonUtils.sh
else
   . $RDK_PATH/utils.sh
fi

#RETRY DELAY in secs
RETRY_DELAY=60
DCM_SKIP_RETRY_FLAG='/tmp/dcm_not_configured'
DCM_CONF="/tmp/DCMSettings.conf"
#Preserve active image name in /tmp/currently_running_image_name
CDL_FLASHED_IMAGE="/opt/cdl_flashed_file_name"
PREVIOUS_FLASHED_IMAGE="/opt/previous_flashed_file_name"
CURRENTLY_RUNNING_IMAGE="/tmp/currently_running_image_name"
WAREHOUSE_ENV="$RAMDISK_PATH/warehouse_mode_active"
FW_STATE_UNINITIALIZED=0
MIB_STATUS_FILE="/opt/fwdnldstatus.txt"
WAREHOUSE_ENV="$RAMDISK_PATH/warehouse_mode_active"

#Log framework to print timestamp and source script name
swupdateLog()
{
    echo "`/bin/timestamp`: $0: $*"
}

eventSender()
{
    if [ -f $IARM_EVENT_BINARY_LOCATION/IARM_event_sender ]; then
        $IARM_EVENT_BINARY_LOCATION/IARM_event_sender $1 $2
    fi
}

#this is to avoid posting events and state changes when deviceInitiatedFWDnld.sh is already in progress.
if [ -f /tmp/DIFD.pid ]; then
    pid=`cat /tmp/DIFD.pid`
    if [ -d /proc/$pid ]; then
	processName=`cat /proc/$pid/cmdline`
        swupdateLog "proc entry process name: $processName"
	if [ -z "${processName##*deviceInitiatedFWDnld.sh*}" ]; then
            swupdateLog "[$0]: proc entry cmdline and process name matched."
            swupdateLog "device initiated firmware download is already in progress.."
            swupdateLog "So Exiting without triggering device initiated firmware download."
            if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
               MAINT_FWDOWNLOAD_INPROGRESS=15   
               eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_INPROGRESS
            fi
            #file lock /tmp/DIFD.pid will be cleared once first instance of deviceInitiatedFWDnld.sh is complete
            exit 0
        fi
    fi
fi

#sending the IARM event initially to set the firmware upgrade state to Uninitialized
eventSender "FirmwareStateEvent" $FW_STATE_UNINITIALIZED

if [ -f /opt/curl_progress ]; then
    rm /opt/curl_progress
fi

sed -i '/FwUpdateState|.*/d' $MIB_STATUS_FILE
echo "FwUpdateState|Uninitialized" >> $MIB_STATUS_FILE

# Adding a sleep of 1 minute to avoid the initial 
# CPU load due to ip address check
sleep 90

if [ -f $CDL_FLASHED_IMAGE ]
then
    myFWVersion=`grep "^imagename" /version.txt | cut -d ':' -f2`
    cdlFlashedFileName=`cat $CDL_FLASHED_IMAGE`
    echo "$cdlFlashedFileName" | grep -q "$myFWVersion"
    if [ $? -ne 0 ]; then
        swupdateLog "Looks like previous upgrade failed but flashed image status is showing success"
        if [ -f $PREVIOUS_FLASHED_IMAGE ]; then
            prevCdlFlashedFileName=`cat $PREVIOUS_FLASHED_IMAGE`
            echo "$prevCdlFlashedFileName" | grep -q "$myFWVersion"
            if [ $? -eq 0 ]; then
                swupdateLog "Updating /tmp/currently_running_image_name with previous successful flashed imagename"
                cp $PREVIOUS_FLASHED_IMAGE $CURRENTLY_RUNNING_IMAGE
            fi
        else
            swupdateLog "Previous flashed file name not found !!! "
            swupdateLog "Updating currently_running_image_name with cdl_flashed_file_name ... "
            cp $CDL_FLASHED_IMAGE $CURRENTLY_RUNNING_IMAGE
        fi
    else
        #Save succesfully flashed file name to identify the previous flashed image for next upgrades
        cp $CDL_FLASHED_IMAGE $PREVIOUS_FLASHED_IMAGE
        cp $CDL_FLASHED_IMAGE $CURRENTLY_RUNNING_IMAGE
    fi
else
    #DELIA-20725: During  bootup with PCI image, it tries to create /tmp/currently_running_image_name from /opt/cdl_flashed_file_name which is missing results to perform CDL again for same image.
    #Hence, update the currently running imagename with from the imagename in version.txt.
    swupdateLog "cdl_flashed_file_name file not found !!! "
    swupdateLog "Updating currently_running_image_name with version.txt ..."
    currentImage=`grep "^imagename" /version.txt | cut -d ':' -f2`
    currentImage=$currentImage-signed.bin
    echo $currentImage > $PREVIOUS_FLASHED_IMAGE
    echo $currentImage > $CURRENTLY_RUNNING_IMAGE
fi

# ESTB IP address check
loop=1
while [ $loop -eq 1 ]
do
    estbIp=`getIPAddress`
    if [ "X$estbIp" == "X" ]; then
        sleep 10
    else
        if [ "$IPV6_ENABLED" = "true" ]; then
            if [ "Y$estbIp" != "Y$DEFAULT_IP" ] && [ -f $WAREHOUSE_ENV ]; then
                loop=0
            elif [ ! -f /tmp/estb_ipv4 ] && [ ! -f /tmp/estb_ipv6 ]; then
                sleep 10
            elif [ "Y$estbIp" == "Y$DEFAULT_IP" ] && [ -f /tmp/estb_ipv4 ]; then
                sleep 10
            else
                loop=0
            fi
        else
            if [ "Y$estbIp" == "Y$DEFAULT_IP" ]; then
                 sleep 10
            else
                 loop=0
            fi
        fi
    fi
done

### main app
retryCount=0
if [ -f $DCM_SKIP_RETRY_FLAG ]; then
     swupdateLog "Device is not configured for DCM. Ignoring attemps for retrieving urn:settings:CheckSchedule:cron "
fi

while [ $retryCount -le 10 ] && [ ! -f $DCM_SKIP_RETRY_FLAG ]
do
    retryCount=$((retryCount + 1))
      if [ -f "$DCM_CONF" ] ; then
        cron=`cat $DCM_CONF | grep 'urn:settings:CheckSchedule:cron' | cut -d '=' -f2`
        if [ -n "$cron" ]; then
            swupdateLog "Triggering deviceInitiatedFWDnld.sh with no retries"
            sh $RDK_PATH/deviceInitiatedFWDnld.sh 0 1 >> /opt/logs/swupdate.log 2>&1 &
            exit 0
        else
            swupdateLog "Failed to read  'urn:settings:CheckSchedule:cron' from /tmp/DCMSettings.conf."
            swupdateLog "Triggering deviceInitiatedFWDnld.sh with 3 retries"
            sh $RDK_PATH/deviceInitiatedFWDnld.sh 3 1 >> /opt/logs/swupdate.log 2>&1 &
            exit 0
        fi
    elif [ -f $WAREHOUSE_ENV ]; then
        break
    else
        swupdateLog "$DCM_CONF file is missing."
        sleep $RETRY_DELAY
      fi
done

swupdateLog "Triggering deviceInitiatedFWDnld.sh with 3 retries"
sh $RDK_PATH/deviceInitiatedFWDnld.sh 3 1 >> /opt/logs/swupdate.log 2>&1 &
exit 0

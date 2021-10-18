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
## Retried every 1 hour 3 times for any of the following failures
##    *  Check local version failure
##    * Failure to talk to cloud (wget failure)
##    * CDL failure
##################################################################

. /etc/include.properties
. /etc/device.properties

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

if [ "$DEVICE_TYPE" == "mediaclient" ]; then
    . /etc/common.properties 
    if [ -f $RDK_PATH/utils.sh ]; then
       . $RDK_PATH/utils.sh
   
    fi

     if [ -f $RDK_PATH/commonUtils.sh ]; then

       . $RDK_PATH/commonUtils.sh
     fi
else
    if [ -f $RDK_PATH/commonUtils.sh ];then
       . $RDK_PATH/commonUtils.sh
    fi
    if [ -f $RDK_PATH/snmpUtils.sh ];then
       . $RDK_PATH/snmpUtils.sh
    fi
fi

if [ -f $RDK_PATH/peripheral_firmware_dndl.sh ]; then
    . $RDK_PATH/peripheral_firmware_dndl.sh
fi

if [ -f $RDK_PATH/bundleUtils.sh ]; then
    . $RDK_PATH/bundleUtils.sh
fi

# initialize partnerId
if [ -f $RDK_PATH/getPartnerId.sh ]; then
    . $RDK_PATH/getPartnerId.sh
fi

# override env if RFC desires
if [ -f $RDK_PATH/rfcOverrides.sh ]; then
    . $RDK_PATH/rfcOverrides.sh
fi

# initialize accountId
if [ -f $RDK_PATH/getAccountId.sh ]; then
    . $RDK_PATH/getAccountId.sh
fi

IARM_EVENT_BINARY_LOCATION=/usr/bin
if [ ! -f /etc/os-release ]; then
    IARM_EVENT_BINARY_LOCATION=/usr/local/bin
fi

eventSender()
{
    if [ -f $IARM_EVENT_BINARY_LOCATION/IARM_event_sender ];
    then
        $IARM_EVENT_BINARY_LOCATION/IARM_event_sender $1 $2
    fi
}



IMAGE_FWDNLD_UNINITIALIZED=0
IMAGE_FWDNLD_DOWNLOAD_INPROGRESS=1
IMAGE_FWDNLD_DOWNLOAD_COMPLETE=2
IMAGE_FWDNLD_DOWNLOAD_FAILED=3
IMAGE_FWDNLD_FLASH_INPROGRESS=4
IMAGE_FWDNLD_FLASH_COMPLETE=5
IMAGE_FWDNLD_FLASH_FAILED=6

#Firmware Upgrade states
FW_STATE_REQUESTING=1
FW_STATE_DOWNLOADING=2
FW_STATE_FAILED=3
FW_STATE_DOWNLOAD_COMPLETE=4
FW_STATE_VALIDATION_COMPLETE=5
FW_STATE_PREPARING_TO_REBOOT=6

#maintaince states
MAINT_FWDOWNLOAD_COMPLETE=8
MAINT_FWDOWNLOAD_ERROR=9
MAINT_FWDOWNLOAD_ABORTED=10
MAINT_CRITICAL_UPDATE=11
MAINT_REBOOT_REQUIRED=12
MAINT_FWDOWNLOAD_INPROGRESS=15

isCriticalUpdate=false # setting default value as false

maintenance_error_flag=0

#Upgrade events
FirmwareStateEvent="FirmwareStateEvent"
ImageDwldEvent="ImageDwldEvent"

## RETRY DELAY in secs
RETRY_DELAY_XCONF=60
RETRY_SHORT_DELAY_XCONF=10

## RETRY COUNT
RETRY_COUNT=3
CB_RETRY_COUNT=1

## File to save curl/wget response
FILENAME="$PERSISTENT_PATH/response.txt"

## File to save http code and curl progress
HTTP_CODE="$PERSISTENT_PATH/xconf_curl_httpcode"
CURL_PROGRESS="$PERSISTENT_PATH/curl_progress"

if [ -f /usr/bin/rdkssacli ] && [ -f /opt/certs/devicecert_1.pk12 ]; then
    useXpkiMtlsLogupload="true"
else
    useXpkiMtlsLogupload="false"
fi

if [ "$DEVICE_NAME" = "LLAMA" ] || [ "$DEVICE_NAME" = "XiOne" ]; then
    ##File to save pid
    CURL_PID_FILE="/tmp/.curl.pid"
    FWDNLD_PID_FILE="/tmp/.fwdnld.pid"
    PWR_STATE_LOG="/opt/logs/pwrstate.log"

    echo "$$" > $FWDNLD_PID_FILE

    if [ -f /usr/bin/pwrstate_notifier ]; then
         /usr/bin/pwrstate_notifier &> $PWR_STATE_LOG &
    fi

    PID_PWRSTATE=`pidof pwrstate_notifier`
    trap 'interrupt_download' 15
fi

if [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
    ##File to save pid
    CURL_PID_FILE="/tmp/.curl.pid"
    FWDNLD_PID_FILE="/tmp/.fwdnld.pid"
    echo "$$" > $FWDNLD_PID_FILE
    trap 'interrupt_download_onabort' SIGABRT
fi



## PDRI image filename
pdriFwVerInfo=""

## File containing common firmware download state variables
STATUS_FILE="/opt/fwdnldstatus.txt"

##START RDKALL-966

DelayDownloadXconf=0

REBOOT_PENDING_DELAY=2

## Hour and Minute of the New Cron Jod for Delay Download
NewCronHr=0
NewCronMin=0

##END RDKALL-966

## Flag to disable STATUS_FILE updates in case of PDRI upgrade
disableStatsUpdate="no"

## Timezone file for all platforms Gram/Fles boxes.
TIMEZONEDST="/opt/persistent/timeZoneDST"

WAREHOUSE_ENV="$RAMDISK_PATH/warehouse_mode_active"
## Capabilities of the current box
CAPABILITIES='&capabilities="rebootDecoupled"&capabilities="RCDL"&capabilities="supportsFullHttpUrl"'

## curl URL and options
imageHTTPURL=""
serverUrl=""
CB_SIGNED_REQUEST=""
CLOUD_URL=""
CURL_OPTION="-w"
DnldURLvalue="/opt/.dnldURL"

## Status of each upgrade
pci_upgrade_status=1
pdri_upgrade_status=1
peripheral_upgrade_status=1

## stores timezone value
zoneValue=""

#$ TLS values and timeouts
CURL_TLS_TIMEOUT=30
TLS="--tlsv1.2"
TLSRet=""
curl_result=1

DIRECT_BLOCK_FILENAME="/tmp/.lastdirectfail_cdl"
CB_BLOCK_FILENAME="/tmp/.lastcodebigfail_cdl"

## Download in progress flags
SNMP_CDL_FLAG="/tmp/device_initiated_snmp_cdl_in_progress"
ECM_CDL_FLAG="/tmp/ecm_initiated_cdl_in_progress"
if [ "$HTTP_CDL_FLAG" == "" ]; then
    HTTP_CDL_FLAG="/tmp/device_initiated_rcdl_in_progress"
fi
DOWNLOAD_IN_PROGRESS="Download In Progress"
UPGRADE_IN_PROGRESS="Flashing In Progress"
dnldInProgressFlag="/tmp/.imageDnldInProgress"

# NLMON Route and DNS flagss
# AF_INET protocols are from /usr/include/linux/socket.h (in Linux)
PING=/bin/ping
RESOLV_FILE=/etc/resolv.dnsmasq
GATEWAYIP_FILE="/tmp/.GatewayIP_dfltroute"
ROUTE_FLAG="/tmp/route_available"
ROUTE_FLAG_MAX_CHECK=5
AF_INET="IPV4"
AF_INET6="IPV6"

if [ -z $LOG_PATH ]; then
    LOG_PATH="/opt/logs/"
fi

if [ "$DEVICE_TYPE" == "mediaclient" ]; then
   if [ "$DEVICE_NAME" = "LLAMA" ] || [ "$DEVICE_NAME" = "PLATCO" ]; then
      #For Placto & LLAMA devices
      STREAMING=`grep "enabled" /sys/class/tsync/enable | awk -F':' '{printf $2}'`
   elif [ "$DEVICE_NAME" = "XiOne" ]; then
      #For Xione device
      STREAMING=`redis-cli get video.codec`
   else
      #For other media-client devices
      STREAMING=`grep "pts" /proc/brcm/video_decoder`
   fi

   VIDEO=$STREAMING

   LOWSPEED=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.SWDLSpLimit.LowSpeed 2>&1 > /dev/null)
   if [ $LOWSPEED -eq 0 ]; then
      LOWSPEED=12800
   fi

   ## Throttle Enabled Variables
   if [ ! -z "$VIDEO" ] && [ "$VIDEO" != "None" ]; then
      isThrottleEnabled=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.SWDLSpLimit.Enable 2>&1 > /dev/null)
      echo "isThrottleEnabled:$isThrottleEnabled"
      TOPSPEED=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.SWDLSpLimit.TopSpeed 2>&1 > /dev/null)
      if [ $TOPSPEED -eq 0 ]; then
         TOPSPEED=1280000
      elif [ $LOWSPEED -gt $TOPSPEED ]; then
         LOWSPEED=12800
      fi
  fi
fi

if [ "$DEVICE_TYPE" != "mediaclient" ]; then
    setSNMPEnv
    snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
    if [ ! "$snmpCommunityVal" ]; then 
        echo "Missing the SNMP community string, existing..!"; 
        if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
        then
             eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
        fi
        exit 1;
    fi
fi

if [ -f $PERSISTENT_PATH/swupdate.conf ] && [ $BUILD_TYPE != "prod" ] ; then
    urlString=`grep -v '^[[:space:]]*#' $PERSISTENT_PATH/swupdate.conf`
    echo "$urlString" | grep -q -i "^http.*://"
    if [ $? -ne 0 ]; then
        echo "`Timestamp` Device configured with an invalid overriden URL : $urlString !!! Exiting from Image Upgrade process..!"
        if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
        then
             eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
        fi
        exit 0
    fi
fi

# Autoupdate exclusion based on Xconf
Fwupdate_auto_exclude=`tr181 -D Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.FWUpdate.AutoExcluded.Enable 2>&1 > /dev/null`

# MTLS flag to use secure endpoints
mTlsXConfDownload=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.MTLS.mTlsXConfDownload.Enable 2>&1 > /dev/null)
isMmgbleNotifyEnabled=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.ManageableNotification.Enable 2>&1 > /dev/null)

XCONF_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Sysint.XconfUrl 2>&1)
if [ -z "$XCONF_URL" ]; then
    XCONF_URL="xconf.xcal.tv"
fi

CIXCONF_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Sysint.CIXconfUrl 2>&1)
if [ -z "$CIXCONF_URL" ]; then
    CIXCONF_URL="ci.xconfds.coast.xcal.tv"
fi

DAC15_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Sysint.DAC15CDLUrl 2>&1)
if [ -z "$DAC15_URL" ]; then
    DAC15_URL="dac15cdlserver.ae.ccp.xcal.tv"
fi

DEVXCONF_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Sysint.XconfDEVUrl 2>&1)
if [ -z "$DEVXCONF_URL" ]; then
    DEVXCONF_URL="https://ccpxcb-dt-a001-q.dt.ccp.cable.comcast.com:8095/xconf/swu/stb"
fi

if [ "$Fwupdate_auto_exclude" == "true" ] && [ $BUILD_TYPE != "prod" ] && [ ! $urlString ] ; then
    echo "Device excluded from firmware update. Exiting !!"
    if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
    then
        eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
    fi
    exit 0
fi

if [ -f /tmp/DIFD.pid ]; then
    pid=`cat /tmp/DIFD.pid`
    if [ -d /proc/$pid ]; then
        echo "Device initiated CDL is in progress.."
        echo "Exiting without triggering device initiated firmware download."
        if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
        then
           eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_INPROGRESS
        fi
        exit 0
    fi
fi
echo $$ > /tmp/DIFD.pid

skipUpgrade=0
if [ "$DEVICE_TYPE" != "mediaclient" ] && [ -f $HTTP_CDL_FLAG ] || [ -f $SNMP_CDL_FLAG ] || [ -f $ECM_CDL_FLAG ]; then
    skipUpgrade=1
elif [ "$DEVICE_TYPE" == "mediaclient" ]; then
    if [ -f $STATUS_FILE ]; then
        status=`cat $STATUS_FILE | grep "Status" | cut -d '|' -f2`
    fi
    if [ "$status" == "$DOWNLOAD_IN_PROGRESS" ] || [ "$status" == "$UPGRADE_IN_PROGRESS" ]; then
        if [ -f $dnldInProgressFlag ]; then
            skipUpgrade=1
        fi
    fi
fi

if [ $skipUpgrade -eq 1 ] ; then
    echo "Device/ECM/Previous initiated firmware upgrade in progress."
    t2CountNotify "SYST_ERR_PrevCDL_InProg"
    echo "Exiting without triggering device initiated firmware download."
    if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
    then
        eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
    fi
    exit 0
fi

if [ $# -eq 2 ]; then
    # Retry Count ($1) argument will not be parsed as we will use hardcoded fallback mechanism added in RDK-27491. 
    RETRY_COUNT_XCONF=0                        # Assign 0 as default retry count will be used.
    echo "Retry count passed in first argument=$1 is not used as we follow default retry count=$RETRY_COUNT_XCONF for fallback mechanism"
    triggerType=$2                             # Set the Image Upgrade trigger Type
else
    echo "Usage: sh <SCRIPT> <failure retry count> <Image trigger Type>"
    echo "     failure retry count: This value from DCM settings file, if not \"0\""
    echo "     Image  trigger Type : Bootup(1)/scheduled(2)/tr69 or SNMP triggered upgrade(3)/App triggered upgrade(4)/(5) Delayed Download"
    if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
    then
        eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
    fi
    exit 0
fi

if [ $triggerType -eq 1 ]; then
    echo "`Timestamp` Image Upgrade During Bootup ..!"
elif [ $triggerType -eq 2 ]; then
    echo "`Timestamp` Scheduled Image Upgrade using cron ..!"
elif [ $triggerType -eq 3 ]; then # Existing SNMP/TR69 upgrades are triggred with type 3
    echo "`Timestamp` TR-69/SNMP triggered Image Upgrade ..!"
elif [ $triggerType -eq 4 ]; then
     echo "`Timestamp` App triggered Image Upgrade ..!"
elif [ $triggerType -eq 5 ]; then
     echo "`Timestamp` Delayed Trigger Image Upgrade ..!"
elif [ $triggerType -eq 6 ]; then
     echo "`Timestamp` State Red Image Upgrade ..!"
else
     echo "`Timestamp` Invalid Upgrade request : $triggerType !"
     if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
     then
        eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
     fi
     exit 0
fi

if [ -f $CURL_PROGRESS ]; then
    rm $CURL_PROGRESS
fi

EnableOCSPStapling="/tmp/.EnableOCSPStapling"
EnableOCSP="/tmp/.EnableOCSPCA"

#Cert ops STB Red State recovery RDK-30717
stateRedSprtFile="/lib/rdk/stateRedRecovery.sh"
stateRedFlag="/tmp/stateRedEnabled"

STATE_RED_LOG_FILE=$LOG_PATH/"swupdate.log"
stateRedlog ()
{
    echo "`Timestamp` : $*" >> "$STATE_RED_LOG_FILE"
}

#isStateRedSupported; check if state red supported
isStateRedSupported()
{
    stateRedSupport=0
    if [ -f $stateRedSprtFile ]; then
        stateRedSupport=1
    else
        stateRedSupport=0
    fi
    return $stateRedSupport
}

#isInStateRed state red status, if set ret 1
#stateRed is local to function
isInStateRed()
{
    stateRed=0
    isStateRedSupported
    stateSupported=$?
    if [ $stateSupported -eq 0 ]; then
         return $stateRed
    fi

    if [ -f $stateRedFlag ]; then
        stateRed=1
    fi
    return $stateRed
}

#unsetStateRed; exit from state red
unsetStateRed()
{
   if [ -f $stateRedFlag ]; then
       stateRedlog "unsetStateRed: Exiting State Red"
       rm -f $stateRedFlag
   fi
}

# forceStateRed - forcing state red; 
# To be used incase of regular software download fails when all tries are exhausted
forceStateRed()
{
    isStateRedSupported
    stateSupported=$?
    if [ $stateSupported -eq 0 ]; then
         return
    fi

    isInStateRed
    stateRedflagset=$?
    if [ $stateRedflagset -eq 1 ]; then
        stateRedlog "forceStateRed: device state red recovery flag already set"
    else
        stateRedlog "forceStateRed: Forcing Setting State Red Recovery Flag"
        rm -f $DIRECT_BLOCK_FILENAME
        rm -f $CB_BLOCK_FILENAME
        touch $stateRedFlag
    fi
}

# checkAndEnterStateRed <curl return code> - enter state red on SSL related error code
checkAndEnterStateRed()
{
    curlReturnValue=$1

    isStateRedSupported
    stateSupported=$?
    if [ $stateSupported -eq 0 ]; then
         return
    fi

    isInStateRed
    stateRedflagset=$?
    if [ $stateRedflagset -eq 1 ]; then
        stateRedlog "checkAndEnterStateRed: device state red recovery flag already set"
        return
    fi

#Enter state red on ssl or cert errors
    case $curlReturnValue in
    35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
        stateRedlog "checkAndEnterStateRed: Curl SSL/TLS error ($curlReturnValue). Set State Red Recovery Flag and Exit!!!"
        rm -f $DIRECT_BLOCK_FILENAME
        rm -f $CB_BLOCK_FILENAME
        rm -f $HTTP_CDL_FLAG
        updateFWDownloadStatus "" "Failure" "" "TLS/SSL Error" "" "" "$runtime" "Failed" "$DelayDownloadXconf"
        touch $stateRedFlag
        exit 1
    ;;
    esac
}
#ends Red state recovery

IsDirectBlocked()
{
    directret=0
    if [ -f $DIRECT_BLOCK_FILENAME ]; then
        modtime=$(($(date +%s) - $(date +%s -r $DIRECT_BLOCK_FILENAME)))
        remtime=$((($DIRECT_BLOCK_TIME/3600) - ($modtime/3600)))
        if [ "$modtime" -le "$DIRECT_BLOCK_TIME" ]; then
            echo "`Timestamp` ImageUpgrade: Last direct failed blocking is still valid for $remtime hrs, preventing direct"
            directret=1
        else
            echo "`Timestamp` ImageUpgrade: Last direct failed blocking has expired, removing $DIRECT_BLOCK_FILENAME, allowing direct"
            rm -f $DIRECT_BLOCK_FILENAME
        fi
    fi

#Cert ops STB Red State recovery RDK-30717
    isInStateRed
    redflagset=$?
    if [ $redflagset -eq 1 ]; then
        directret=0
        stateRedlog "In red state red recovery; always try direct mtls connection"
    fi
    return $directret
}

IsCodeBigBlocked()
{
    codebigret=0
    if [ -f $CB_BLOCK_FILENAME ]; then
        modtime=$(($(date +%s) - $(date +%s -r $CB_BLOCK_FILENAME)))
        cbremtime=$((($CB_BLOCK_TIME/60) - ($modtime/60)))
        if [ "$modtime" -le "$CB_BLOCK_TIME" ]; then
            echo "`Timestamp` ImageUpgrade: Last codebig failed blocking is still valid for $cbremtime mins, preventing codebig"
            codebigret=1
        else
            echo "`Timestamp` ImageUpgrade: Last codebig failed blocking has expired, removing $CB_BLOCK_FILENAME, allowing codebig"
            rm -f $CB_BLOCK_FILENAME
        fi
    fi

#Cert ops STB Red State recovery RDK-30717
    isInStateRed
    redflagset=$?
    if [ $redflagset -eq 1 ]; then
        codebigret=1
        stateRedlog "In red state red recovery; disabling code-big"
    fi

    return $codebigret
}

updateUpgradeFlag ()
{
    if [ "$DEVICE_TYPE" == "mediaclient" ]; then
        flag=$dnldInProgressFlag
    elif [ "$protocol" == "2" ]; then
        flag=$HTTP_CDL_FLAG
    else
        flag=$SNMP_CDL_FLAG
    fi    
    
    if [ "$1" == "create" ]; then
        touch $flag        
    elif [ "$1" == "remove" ]; then
        if [ -f $flag ]; then rm $flag; fi
    fi
}

eventManager()
{
    # Disable the event updates if PDRI upgrade
    if [ "$disableStatsUpdate" == "yes" ]; then
        return 0
    fi

    if [ -f $IARM_EVENT_BINARY_LOCATION/IARM_event_sender ]; then
        $IARM_EVENT_BINARY_LOCATION/IARM_event_sender $1 $2
    else
        echo "Missing the binary $IARM_EVENT_BINARY_LOCATION/IARM_event_sender"
    fi
}

Trigger_RebootPendingNotify()
{
	#Trigger RebootPendingNotification prior to device reboot for all software managed types of reboots
	echo "RDKV_REBOOT : Setting RebootPendingNotification before reboot"
	tr181 -s -v $REBOOT_PENDING_DELAY Device.DeviceInfo.X_RDKCENTRAL-COM_xOpsDeviceMgmt.RPC.RebootPendingNotification 
	echo "RDKV_REBOOT  : RebootPendingNotification SET succeeded"
}
## Function to update Firmware download status in log file /opt/fwdnldstatus.txt
## Args : 1] Protocol
## Args : 2] Upgrade status
## Args : 3] Reboot immediately flag
## Args : 4] Failure Reason
## Args : 5] Download File Version
## Args : 6] Download File Name
## Args : 7] The latest date and time of last execution
## Args : 8] Firmware Update State
## Args : 9] Delay Download Value
updateFWDownloadStatus()
{
    # Disable the update if PDRI upgrade
    if [ "$disableStatsUpdate" == "yes" ]; then
        return 0
    fi

    TEMP_STATUS="/tmp/.fwdnldstatus.txt"
    proto=$1
    status=$2
    reboot=$3
    failureReason=$4
    DnldVersn=$5
    DnldFile=$6
    LastRun=$7
    fwUpdateState=$8
    delayDnld=$9
    numberOfArgs=$#

    if [ "$fwUpdateState" == "" ]; then
        fwUpdateState=`cat $STATUS_FILE | grep FwUpdateState | cut -d '|' -f2`
    fi
    # Check to avoid error in status due error in argument count during logging
    if [ "$numberOfArgs" -ne "9" ]; then
        echo "Error in number of args for logging status in fwdnldstatus.txt"
    fi

    echo "Method|xconf" > $TEMP_STATUS
    echo "Proto|$proto" >> $TEMP_STATUS
    echo "Status|$status" >> $TEMP_STATUS
    echo "Reboot|$reboot" >> $TEMP_STATUS
    echo "FailureReason|$failureReason" >> $TEMP_STATUS
    echo "DnldVersn|$DnldVersn" >> $TEMP_STATUS
    echo "DnldFile|$DnldFile" >> $TEMP_STATUS
    echo "DnldURL|`cat $DnldURLvalue`" >> $TEMP_STATUS
    echo "LastRun|$LastRun" >> $TEMP_STATUS
    echo "FwUpdateState|$fwUpdateState" >> $TEMP_STATUS
    echo "DelayDownload|$delayDnld" >> $TEMP_STATUS
    mv $TEMP_STATUS $STATUS_FILE
}

getaddressType()
{
    if [ "$DEVICE_TYPE" == "mediaclient" ]; then
        retries=0
        while [ ! -f /tmp/estb_ipv4 -a ! -f /tmp/estb_ipv6 ]
        do
            sleep 2
            retries=`expr $retries + 1`
            if [ $retries -eq 10 ]; then
            break;
            fi
        done

        if [ -f /tmp/estb_ipv4 ];then addressType=ipv4; fi
        if [ -f /tmp/estb_ipv6 ];then addressType=ipv6; fi
    else
        addressType=`snmpget -OQv -v 2c -c "$snmpCommunityVal" 192.168.100.1 .1.3.6.1.2.1.69.1.4.6.0`
    fi
    echo $addressType
}

getLocalTime()
{
    timeValue=`date`
    echo "$timeValue"
}    

getTimeZone()
{
    echo "Retrieving the timezone value"
    JSONPATH=/opt
    if [ "$CPU_ARCH" == "x86" ]; then JSONPATH=/tmp; fi
    counter=1
    echo "Reading Timezone value from $JSONPATH/output.json file..."
    while [ ! "$zoneValue" ]
    do
        echo "timezone retry:$counter"
        if [ -f $JSONPATH/output.json ] && [ -s $JSONPATH/output.json ];then
            grep timezone $JSONPATH/output.json | cut -d ":" -f2 | sed 's/[\",]/ /g' > /tmp/.timeZone.txt
        fi
        
        while read entry
        do
            zoneValue=`echo $entry | grep -v 'null'`
            if [ ! -z "$zoneValue" ]; then
                break
            fi
        done < /tmp/.timeZone.txt
        
        if [ $counter -eq 10 ];then
            echo "Timezone retry count reached the limit . Timezone data source is missing"
            break;
        fi
        counter=`expr $counter + 1`
        sleep 6
    done

    if [ ! "$zoneValue" ]; then
        echo "Timezone value from $JSONPATH/output.json is empty, Reading from $TIMEZONEDST file..."
        if [ -f $TIMEZONEDST ] && [ -s $TIMEZONEDST ];then
            zoneValue=`cat $TIMEZONEDST | grep -v 'null'`
            echo "Got timezone using $TIMEZONEDST successfully, value:$zoneValue"
        else
            echo "$TIMEZONEDST file not found, Timezone data source is missing "
        fi
    else
        echo "Got timezone using $JSONPATH/output.json successfully, value:$zoneValue"
    fi
    
    echo "$zoneValue"
}

getFWVersion()
{
    versionTag1=$FW_VERSION_TAG1
    versionTag2=$FW_VERSION_TAG2
    verStr=`cat /version.txt | grep ^imagename:$versionTag1`
    if [ $? -eq 0 ]; then
        echo $verStr | cut -d ":" -f 2
    else
        version=`cat /version.txt | grep ^imagename:$versionTag2 | cut -d ":" -f 2`
        echo $version
    fi
}

getSerialNumber()
{
    serNum=`sh $RDK_PATH/serialNumber.sh`
    echo $serNum
}

# identifies whether it is a VBN or PROD build
getBuildType()
{
    str=$(getFWVersion)

    echo $str | grep -q 'VBN'
    if [[ $? -eq 0 ]] ; then
        echo 'vbn'
    else
        echo $str | grep -q 'PROD'
        if [[ $? -eq 0 ]] ; then
            echo 'prod'
        else
            echo $str | grep -q 'QA'
            if [[ $? -eq 0 ]] ; then
                echo 'qa'
            else
                echo 'dev'
            fi
        fi
    fi
}

sendTLSCodebigRequest()
{
    TLSRet=1
    echo "000" > $HTTP_CODE     # provide a default value in $HTTP_CODE

    if [ "$1" == "XCONF" ]; then
        echo "Attempting $TLS connection to Codebig XCONF server"
        if [ -f /lib/rdk/logMilestone.sh ];then
            sh /lib/rdk/logMilestone.sh "CONNECT_TO_XCONF_CDL"
        fi
        if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
           CURL_CMD="curl $TLS --cert-status --connect-timeout $CURL_TLS_TIMEOUT  -w '%{http_code}\n' -o \"$FILENAME\" \"$CB_SIGNED_REQUEST\" -m 10"
        else
           CURL_CMD="curl $TLS --connect-timeout $CURL_TLS_TIMEOUT  -w '%{http_code}\n' -o \"$FILENAME\" \"$CB_SIGNED_REQUEST\" -m 10"
        fi
        if [ "$BUILD_TYPE" != "prod" ]; then
            echo CURL_CMD: $CURL_CMD
        else
            echo ADDITIONAL_FW_VER_INFO: $pdriFwVerInfo$remoteInfo
        fi
        result= eval $CURL_CMD > $HTTP_CODE
        rc=$?
        if [ $rc -eq 6 ]; then 
            t2CountNotify "xconf_couldnt_resolve"
        fi
    elif [ "$1" == "SSR" ]; then
        echo "Attempting $TLS connection to Codebig SSR server"
        if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
           if [ "$DEVICE_TYPE" == "mediaclient" ]; then
              if [ "$isThrottleEnabled" = "true" ] && [ ! -z "$VIDEO" ] && [ "$cloudImmediateRebootFlag" != "true" ]; then
                 echo "Throttle is enabled and Video is Streaming"
                 CURL_CMD="curl $TLS --cert-status --connect-timeout $CURL_TLS_TIMEOUT  -H '$2' -w '%{http_code}\n' -fgLo $DIFW_PATH/$UPGRADE_FILE '$serverUrl' --speed-limit $LOWSPEED --limit-rate $TOPSPEED > $HTTP_CODE"
              else
                 if [ "$isThrottleEnabled" = "true" ] && [ ! -z "$VIDEO" ] && [ "$cloudImmediateRebootFlag" = "true" ]; then
                    echo "Throttle is enabled and Video is Streaming but cloudImmediateRebootFlag is true"
                    echo "Continuing with the Unthrottle mode"
                 else
                    echo "Throttle is disabled"
                 fi
                 CURL_CMD="curl $TLS --cert-status --connect-timeout $CURL_TLS_TIMEOUT  -H '$2' -w '%{http_code}\n' -fgLo $DIFW_PATH/$UPGRADE_FILE '$serverUrl' --speed-limit $LOWSPEED > $HTTP_CODE"
              fi
           else
              CURL_CMD="curl $TLS --cert-status --connect-timeout $CURL_TLS_TIMEOUT  -H '$2' -w '%{http_code}\n' -fgLo $DIFW_PATH/$UPGRADE_FILE '$serverUrl' > $HTTP_CODE"
           fi
        else
           if [ "$DEVICE_TYPE" == "mediaclient" ]; then
              if [ "$isThrottleEnabled" = "true" ] && [ ! -z "$VIDEO" ] && [ "$cloudImmediateRebootFlag" != "true" ]; then
                  echo "Throttle is enabled and Video is Streaming"
                  CURL_CMD="curl $TLS --connect-timeout $CURL_TLS_TIMEOUT  -H '$2' -w '%{http_code}\n' -fgLo $DIFW_PATH/$UPGRADE_FILE '$serverUrl' --speed-limit $LOWSPEED --limit-rate $TOPSPEED > $HTTP_CODE"
              else
                 if [ "$isThrottleEnabled" = "true" ] && [ ! -z "$VIDEO" ] && [ "$cloudImmediateRebootFlag" = "true" ]; then
                    echo "Throttle is enabled and Video is Streaming but cloudImmediateRebootFlag is true"
                    echo "Continuing with the Unthrottle mode"
                 else
                    echo "Throttle is disabled"
                 fi
                 CURL_CMD="curl $TLS --connect-timeout $CURL_TLS_TIMEOUT  -H '$2' -w '%{http_code}\n' -fgLo $DIFW_PATH/$UPGRADE_FILE '$serverUrl' --speed-limit $LOWSPEED > $HTTP_CODE"
              fi
           else
              CURL_CMD="curl $TLS --connect-timeout $CURL_TLS_TIMEOUT  -H '$2' -w '%{http_code}\n' -fgLo $DIFW_PATH/$UPGRADE_FILE '$serverUrl' > $HTTP_CODE"
           fi
        fi
        if [ "$BUILD_TYPE" != "prod" ]; then
            echo CURL_CMD: $CURL_CMD
        else
            echo ADDITIONAL_FW_VER_INFO: $pdriFwVerInfo$remoteInfo
        fi
        if [ "$DEVICE_NAME" = "LLAMA" ] || [ "$DEVICE_NAME" = "XiOne" ]  || [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
              result= eval $CURL_CMD &> $CURL_PROGRESS &
              echo "$!" > $CURL_PID_FILE
              CurlPid=`cat $CURL_PID_FILE`
              wait $CurlPid
        else
              result= eval $CURL_CMD &> $CURL_PROGRESS
        fi
        rc=$?
        if [ $rc -eq 28 ]; then
            # Curl returns 28 if speed is less than 100 kbit/sec
            # curl: (28) Operation too slow. Less than 12800 bytes/sec transferred the last 30 seconds
            echo "CDL is suspended because speed is below 100 kbit/second"
        fi

        if [ $rc -eq 22 ]; then 
            t2CountNotify "swdl_failed"
        elif [ $rc -eq 18 ] || [ $rc -eq 7 ]; then
            t2CountNotify "swdl_failed_$rc"
        fi

    fi
    TLSRet=$?
    if [ -f $CURL_PROGRESS ]; then
        rm $CURL_PROGRESS
    fi
    case $TLSRet in
    35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
        echo "HTTPS $TLS failed to connect to Codebig $1 server with curl error code $TLSRet" >> $LOG_PATH/tlsError.log
    ;;
    esac
    echo "Curl return code : $TLSRet"
    checkAndEnterStateRed $TLSRet
}

sendTLSRequest()
{
    TLSRet=1
    echo "000" > $HTTP_CODE     # provide a default value to avoid possibility of an old value remaining

    if [ "$FORCE_MTLS" == "true" ]; then
        echo "MTLS prefered"
        mTlsXConfDownload="true"
    fi
    isInStateRed
    stateRed=$?
    if [ "0x$stateRed" == "0x1" ]; then
        stateRedlog "state red recovery attempting MTLS connection to XCONF server"

        if [ -f /etc/ssl/certs/statered.pem ]; then
            if [ ! -f /usr/bin/GetConfigFile ]; then
                stateRedlog "Error: State Red GetConfigFile Not Found"
                exit 127
            fi
            ID="/tmp/stateredidx"
            if [ ! -f $ID ]; then 
                GetConfigFile $ID
            fi
            if [ -f $ID ]; then
                if [ "$1" == "XCONF" ]; then
                    CURL_CMD="curl -vv $TLS --cert /etc/ssl/certs/statered.pem --key /tmp/stateredidx --connect-timeout $CURL_TLS_TIMEOUT $CURL_OPTION '%{http_code}\n' -d \"$JSONSTR\" -o \"$FILENAME\" \"$CLOUD_URL\" -m 10"
                elif  [ "$1" == "SSR" ]; then
                    CURL_CMD="curl -vv $TLS --cert /etc/ssl/certs/statered.pem --key /tmp/stateredidx --connect-timeout $CURL_TLS_TIMEOUT $CURL_OPTION '%{http_code}\n' -fgLO \"$imageHTTPURL\" > $HTTP_CODE"
                else
                    stateRedlog "Error: State Red Valid [$1] Configuation value not passed"
                fi
                if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
                    CURL_CMD="$CURL_CMD --cert-status"
                fi
                stateRedlog "State Red Recovery CURL_CMD: [$CURL_CMD]"
                result= eval $CURL_CMD > $HTTP_CODE
            else
                stateRedlog "Error: State Red Recovery config not found"
                exit 127
            fi
        else
            stateRedlog "Error: State Red Recovery, cert not found"
            exit 127
        fi

    elif [ "$1" == "XCONF" ]; then
        echo "Attempting $TLS connection to XCONF server"
        if [ -f /lib/rdk/logMilestone.sh ];then
            sh /lib/rdk/logMilestone.sh "CONNECT_TO_XCONF_CDL"
        fi

        if [ "$mTLS_RPI" == "true" ] ; then
            CURL_CMD="curl -vv --cert-type pem --cert /etc/ssl/certs/refplat-xconf-cpe-clnt.xcal.tv.cert.pem --key /tmp/xconf-file.tmp -w '%{http_code}\n' -d \"$JSONSTR\" -o \"$FILENAME\" \"$CLOUD_URL\" --connect-timeout 10 -m 10"

        else
            if [ $useXpkiMtlsLogupload == "true" ]; then
                CURL_CMD="curl $TLS --cert-type P12 --cert /opt/certs/devicecert_1.pk12:$(/usr/bin/rdkssacli "{STOR=GET,SRC=kquhqtoczcbx,DST=/dev/stdout}") --connect-timeout $CURL_TLS_TIMEOUT $CURL_OPTION '%{http_code}\n' -d \"$JSONSTR\" -o \"$FILENAME\" \"$CLOUD_URL\" -m 10"    
            else    
                if [ -f /etc/ssl/certs/staticXpkiCrt.pk12 ]; then
                    if [ ! -f /usr/bin/GetConfigFile ]; then
                        echo "Error: GetConfigFile Not Found"
                        exit 127
                    fi
                    ID="/tmp/.cfgStaticxpki"
                    if [ ! -f "$ID" ]; then
                        GetConfigFile $ID
                    fi
                    if [ ! -f "$ID" ]; then
                        echo "Error: Getconfig file failed"
                    fi
                    CURL_CMD="curl $TLS --cert-type P12 --cert /etc/ssl/certs/staticXpkiCrt.pk12:$(cat $ID) --connect-timeout $CURL_TLS_TIMEOUT $CURL_OPTION '%{http_code}\n' -d \"$JSONSTR\" -o \"$FILENAME\" \"$CLOUD_URL\" -m 10"
                else
                    CURL_CMD="curl $TLS --connect-timeout $CURL_TLS_TIMEOUT $CURL_OPTION '%{http_code}\n' -d \"$JSONSTR\" -o \"$FILENAME\" \"$CLOUD_URL\" -m 10"
                fi
            fi
        fi
        if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
           CURL_CMD="$CURL_CMD --cert-status"
        fi

        if [ "$BUILD_TYPE" != "prod" ]; then
           echo CURL_CMD: `echo "$CURL_CMD" | sed 's/devicecert_1.*-connect/devicecert_1.pk12<hidden key>--connect/' | sed 's/staticXpkiCr.*connect/staticXpkiCrt.pk12<hidden key>--connect/'`
        else 
           echo ADDITIONAL_FW_VER_INFO: $pdriFwVerInfo$remoteInfo
        fi
        result= eval $CURL_CMD > $HTTP_CODE
        rc=$?
        if [ $rc -eq 6 ]; then 
           t2CountNotify "xconf_couldnt_resolve" 
        fi
    elif [ "$1" == "SSR" ]; then
        echo "Attempting $TLS connection to SSR server" 
        if [ "$mTlsXConfDownload" == "true" ]; then
            if [ -d /etc/ssl/certs ]; then
                if [ ! -f /usr/bin/GetConfigFile ];then
                    echo "Error: GetConfigFile Not Found"
                    exit 127
                fi
                ID="/tmp/uydrgopwxyem"
                if [ ! -f "$ID" ]; then
                    GetConfigFile $ID
                fi
            fi
            if [ "$DEVICE_TYPE" == "mediaclient" ]; then
               if [ "$isThrottleEnabled" = "true" ] && [ ! -z "$VIDEO" ] && [ "$cloudImmediateRebootFlag" != "true" ]; then
                   echo "Throttle is enabled and Video is Streaming"
                   CURL_CMD="curl $TLS --key /tmp/uydrgopwxyem --cert /etc/ssl/certs/cpe-clnt.xcal.tv.cert.pem --connect-timeout $CURL_TLS_TIMEOUT $CURL_OPTION '%{http_code}\n' -fgLO \"$imageHTTPURL\" --speed-limit $LOWSPEED --limit-rate $TOPSPEED > $HTTP_CODE"
               else
                  if [ "$isThrottleEnabled" = "true" ] && [ ! -z "$VIDEO" ] && [ "$cloudImmediateRebootFlag" = "true" ]; then
                     echo "Throttle is enabled and Video is Streaming but cloudImmediateRebootFlag is true"
                     echo "Continuing with the Unthrottle mode"
                  else
                     echo "Throttle is disabled"
                  fi
                  CURL_CMD="curl $TLS --key /tmp/uydrgopwxyem --cert /etc/ssl/certs/cpe-clnt.xcal.tv.cert.pem --connect-timeout $CURL_TLS_TIMEOUT $CURL_OPTION '%{http_code}\n' -fgLO \"$imageHTTPURL\" --speed-limit $LOWSPEED > $HTTP_CODE"
               fi
            else
                CURL_CMD="curl $TLS --key /tmp/uydrgopwxyem --cert /etc/ssl/certs/cpe-clnt.xcal.tv.cert.pem --connect-timeout $CURL_TLS_TIMEOUT $CURL_OPTION '%{http_code}\n' -fgLO \"$imageHTTPURL\" > $HTTP_CODE"
            fi
        else
            if [ "$DEVICE_TYPE" == "mediaclient" ]; then
               if [ "$isThrottleEnabled" = "true" ] && [ ! -z "$VIDEO" ] && [ "$cloudImmediateRebootFlag" != "true" ]; then
                   echo "Throttle is enabled and Video is Streaming"
                   CURL_CMD="curl $TLS --connect-timeout $CURL_TLS_TIMEOUT $CURL_OPTION '%{http_code}\n' -fgLO \"$imageHTTPURL\" --speed-limit $LOWSPEED --limit-rate $TOPSPEED > $HTTP_CODE"
               else
                  if [ "$isThrottleEnabled" = "true" ] && [ ! -z "$VIDEO" ] && [ "$cloudImmediateRebootFlag" = "true" ]; then
                     echo "Throttle is enabled and Video is Streaming but cloudImmediateRebootFlag is true"
                     echo "Continuing with the Unthrottle mode"
                  else
                     echo "Throttle is disabled"
                  fi
                  CURL_CMD="curl $TLS --connect-timeout $CURL_TLS_TIMEOUT $CURL_OPTION '%{http_code}\n' -fgLO \"$imageHTTPURL\" --speed-limit $LOWSPEED > $HTTP_CODE"
               fi
            else
               CURL_CMD="curl $TLS --connect-timeout $CURL_TLS_TIMEOUT $CURL_OPTION '%{http_code}\n' -fgLO \"$imageHTTPURL\" > $HTTP_CODE"
            fi
        fi

        if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
           CURL_CMD="$CURL_CMD --cert-status"
        fi

        echo CURL_CMD: `echo "$CURL_CMD" | sed 's/devicecert_1.*-connect/devicecert_1.pk12<hidden key>--connect/' | sed 's/staticXpkiCr.*connect/staticXpkiCrt.pk12<hidden key>--connect/'`
        if [ "$BUILD_TYPE" != "prod" ]; then
           echo CURL_CMD: `echo "$CURL_CMD" | sed 's/devicecert_1.*-connect/devicecert_1.pk12<hidden key>--connect/' | sed 's/staticXpkiCr.*connect/staticXpkiCrt.pk12<hidden key>--connect/'`
        else
           echo ADDITIONAL_FW_VER_INFO: $pdriFwVerInfo$remoteInfo
        fi
        if [ "$DEVICE_NAME" = "LLAMA" ] || [ "$DEVICE_NAME" = "XiOne" ] || [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
              result= eval $CURL_CMD &> $CURL_PROGRESS &
              echo "$!" > $CURL_PID_FILE
              CurlPid=`cat $CURL_PID_FILE`
              wait $CurlPid
        else
              result= eval $CURL_CMD &> $CURL_PROGRESS
        fi
        rc=$?
        if [ $rc -eq 28 ]; then
            # Curl returns 28 if speed is less than 100 kbit/sec
            # curl: (28) Operation too slow. Less than 12800 bytes/sec transferred the last 30 seconds
            echo "CDL is suspended because speed is below 100 kbit/second"
        fi

        if [ $rc -eq 22 ]; then 
            t2CountNotify "swdl_failed"
        elif [ $rc -eq 18 ] || [ $rc -eq 7 ]; then
            t2CountNotify "swdl_failed_$rc"
        fi
    fi
    TLSRet=$?
    if [ -f $CURL_PROGRESS ]; then
        rm $CURL_PROGRESS
    fi 
    case $TLSRet in
    35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
        echo "HTTPS $TLS failed to connect to $1 server with curl error code $TLSRet" >> $LOG_PATH/tlsError.log
    ;;
    esac
    echo "Curl return code : $TLSRet"
    if [ "0xTLSRet" != "0x0" ]; then
        checkAndEnterStateRed $TLSRet
    fi
}

httpTLSDownload () {
    ret=1
    http_code="000"

    echo "Trying to communicate with SSR via TLS server"
    sendTLSRequest "SSR"
    ret=$TLSRet
    http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
    echo "`Timestamp` httpTLSDownload: SSR Image download ret : $ret"
    if [ $ret -ne 0 ]; then
        rm -rf $DIFW_PATH/$UPGRADE_FILE
    fi

    if [ $ret -ne 0 ] || [ "$http_code" != "200" ]; then
       echo "`Timestamp` Failed to download image from normal SSR code download server with ret:$ret, httpcode:$http_code"
       if [ "$DEVICE_TYPE" == "mediaclient" ]; then
          if [ "x$http_code" = "x000" ]; then
	     failureReason="Image Download Failed - Unable to connect"
          elif [ "x$http_code" = "x404" ]; then
	     failureReason="Image Download Failed - Server not Found"
          elif [[ "$http_code" -ge 500 ]] && [[ "$http_code" -le 511 ]]; then
	     failureReason="Image Download Failed - Error response from server"
          else
	     failureReason="Image Download Failed - Unknown"
          fi
          updateFWDownloadStatus "$cloudProto" "Failure" "$cloudImmediateRebootFlag" "$failureReason" "$dnldFWVersion" "$UPGRADE_FILE" "$runtime" "Failed" "$DelayDownloadXconf"
          eventManager $ImageDwldEvent $IMAGE_FWDNLD_DOWNLOAD_FAILED       
       else
          if [ "x$http_code" = "x000" ]; then
	     failureReason="ESTB Download Failure"
          fi
          updateFWDownloadStatus "$cloudProto" "Failure" "$cloudImmediateRebootFlag" "$failureReason" "$dnldFWVersion" "$UPGRADE_FILE" "$runtime" "Failed" "$DelayDownloadXconf"
          eventManager $ImageDwldEvent $IMAGE_FWDNLD_DOWNLOAD_FAILED
       fi
    fi

    return $ret
}

httpCodebigDownload () {        
    domainName=`echo $imageHTTPURL | awk -F/ '{print $3}'`
    imagedownloadHTTPURL=`echo $imageHTTPURL | sed -e "s|.*$domainName||g"`
    ret=1
    http_code="000"
    request_type=1
    if [ "$domainName" == "$DAC15_URL" ]; then
        request_type=14
    fi

    SIGN_CMD="GetServiceUrl $request_type \"$imagedownloadHTTPURL\""
    eval $SIGN_CMD > /tmp/.signedRequest
    if [ -s /tmp/.signedRequest ]
    then
        echo "GetServiceUrl success"
    else
        echo "GetServiceUrl failed"
        exit 1
    fi
    cbSignedimageHTTPURL=`cat /tmp/.signedRequest`
    rm -f /tmp/.signedRequest

    echo "`Timestamp` Trying to communicate with SSR via CodeBig server"
    # Work around for resolving SSR url encoded location issue
    # Correcting stb_cdl location in CB signed request
    cbSignedimageHTTPURL=$(sed 's|stb_cdl%2F|stb_cdl/|g' <<< $cbSignedimageHTTPURL)
    eventManager $ImageDwldEvent $IMAGE_FWDNLD_DOWNLOAD_INPROGRESS
    serverUrl=`echo $cbSignedimageHTTPURL | sed -e "s|&oauth_consumer_key.*||g"`
    authorizationHeader=`echo $cbSignedimageHTTPURL | sed -e "s|&|\", |g" -e "s|=|=\"|g" -e "s|.*oauth_consumer_key|oauth_consumer_key|g"`
    authorizationHeader="Authorization: OAuth realm=\"\", $authorizationHeader\""
    sendTLSCodebigRequest "SSR" "$authorizationHeader"
    ret=$TLSRet
    http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
    echo "`Timestamp` httpCodebigDownload: SSR Codebig Image download ret : $ret"

    if [ "$http_code" != "200" ]; then
        rm -rf $DIFW_PATH/$UPGRADE_FILE
    fi 

    return $ret
}

httpDownload ()
{
    http_code="000"
    httpretry=0
    httpcbretry=0

    if [ $UseCodebig -eq 1 ]; then
        echo "`Timestamp` httpDownload: Codebig is enabled UseCodebig=$UseCodebig"
        if [ "$DEVICE_TYPE" = "mediaclient" ]; then
            # Use Codebig connection connection on XI platforms
            IsCodeBigBlocked
            skipcodebig=$?
            if [ $skipcodebig -eq 0 ]; then
                while [ $httpcbretry -le $CB_RETRY_COUNT ]
                do
                    echo "`Timestamp` httpDownload: Using Codebig Image upgrade connection"
                    httpCodebigDownload
                    ret=$?
                    if [ "$http_code" = "200" ]; then
                       echo "`Timestamp` httpDownload: Codebig Image upgrade Success: ret=$ret httpcode=$http_code"
                       IsDirectBlocked
                       skipDirect=$?
                       if [ $skipDirect -eq 0 ]; then
                           UseCodebig=0
                       fi
                       break
                    elif [ "$http_code" = "404" ]; then
                       echo "`Timestamp` httpDownload: Received 404 response for Codebig Image upgrade, Retry logic not needed"
                       break
                    fi
                    echo "`Timestamp` httpDownload: Codebig Image upgrade return: retry=$httpcbretry ret=$ret httpcode=$http_code"
                    httpcbretry=`expr $httpcbretry + 1`
                    sleep $cbretryDelay
                done
            fi

            if [ "$http_code" = "000" ] ; then
                echo "`Timestamp` httpDownload: Codebig Image upgrade failed: httpcode=$http_code, Switching direct"
                UseCodebig=0
                IsDirectBlocked
                skipdirect=$?
                if [ $skipdirect -eq 0 ]; then 
                    httpTLSDownload
                    ret=$?
                    if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                        echo "`Timestamp` httpDownload: Direct image upgrade failover request failed return=$ret, httpcode=$http_code"
                    else
                        echo "`Timestamp` httpDownload: Direct image upgrade failover request received return=$ret, httpcode=$http_code"
                    fi
                fi
                IsCodeBigBlocked
                skipcodebig=$?
                if [ $skipcodebig -eq 0 ]; then
                    echo "`Timestamp` httpDownload: Codebig Blocking is released"
                fi
            elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                echo "`Timestamp` httpDownload: Codebig Image upgrade failed with httpcode=$http_code"
            fi
        else
            echo "`Timestamp` httpDownload: Codebig Image upgrade is not supported"
        fi
    else
        echo "`Timestamp` httpDownload: Codebig is disabled UseCodebig=$UseCodebig"
        # Use direct connection connection for 3 failures with appropriate backoff/timeout,.
        IsDirectBlocked
        skipdirect=$?
        if [ $skipdirect -eq 0 ]; then
            while [ $httpretry -lt $RETRY_COUNT ]
            do
                echo "`Timestamp` httpDownload: Using Direct Image upgrade connection"
                httpTLSDownload
                ret=$?
                if [ "$http_code" = "200" ];then
                    echo "`Timestamp` httpDownload: Direct Image upgrade Success: ret=$ret httpcode=$http_code"
                    break
                elif [ "$http_code" = "404" ]; then
                    echo "`Timestamp` httpDownload: Received 404 response for Direct Image upgrade, Retry logic not needed"
                    break
                fi
                echo "`Timestamp` httpDownload: Direct Image upgrade return: retry=$httpretry ret=$ret httpcode=$http_code"
                httpretry=`expr $httpretry + 1`
                sleep $retryDelay
            done
        fi

        if [ "$http_code" = "000" ]; then
            if [ "$DEVICE_TYPE" = "mediaclient" ]; then
                echo "`Timestamp` httpDownload: Direct Image upgrade Failed: httpcode=$http_code, attempting codebig"
                # Use Codebig connection connection on XI platforms
                IsCodeBigBlocked
                skipcodebig=$?
                if [ $skipcodebig -eq 0 ]; then
                    while [ $httpcbretry -le $CB_RETRY_COUNT ]
                    do
                        echo "`Timestamp` httpDownload: Using Codebig Image upgrade connection"
                        httpCodebigDownload
                        ret=$?
                        if [ "$http_code" = "200" ]; then
                            echo "`Timestamp` httpDownload: Codebig Image upgrade Success: ret=$ret httpcode=$http_code"
                            UseCodebig=1
                            if [ ! -f $DIRECT_BLOCK_FILENAME ]; then
                                touch $DIRECT_BLOCK_FILENAME
                                echo "`Timestamp` httpDownload: Use CodeBig and Blocking Direct attempts for 24hrs"
                            fi
                            break
                        elif [ "$http_code" = "404" ]; then
                            echo "`Timestamp` httpDownload: Received 404 response for Codebig Image upgrade, Retry logic not needed"
                            break
                        fi
                        echo "`Timestamp` httpDownload: Codebig Image upgrade return: retry=$httpcbretry ret=$ret httpcode=$http_code"
                        httpcbretry=`expr $httpcbretry + 1`
                        sleep $cbretryDelay
                    done

                    if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                        echo "`Timestamp` httpDownload: Codebig Image upgrade failed: ret=$ret httpcode=$http_code"
                        UseCodebig=0
                        if [ ! -f $CB_BLOCK_FILENAME ]; then
                            touch $CB_BLOCK_FILENAME
                            echo "`Timestamp` httpDownload: Switch Direct and Blocking Codebig for 30mins,"
                        fi
                    fi
                fi
            else
                echo "`Timestamp` httpDownload: Codebig Image upgrade is not supported"
            fi
        elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
            echo "`Timestamp` httpDownload: Direct Image upgrade Failed: ret=$ret httpcode=$http_code"
        fi
    fi

    return $ret

}

tftpDownload () {
    # PCI TFTP upgrade of non-client devices doesnt require ESTB side image download
    if [ "x$PDRI_UPGRADE" != "xpdri" ] && [ "$DEVICE_TYPE" != "mediaclient" ]; then
        return 0
    fi
    ret=1
    echo  "`Timestamp` Image download with tftp prtocol"
    if [ -f /tmp/estb_ipv6 ] ; then
        tftp -g [$UPGRADE_LOCATION] -r $UPGRADE_FILE -l $DIFW_PATH/$UPGRADE_FILE -b 16384
    else
        tftp -g  $UPGRADE_LOCATION -r $UPGRADE_FILE -l $DIFW_PATH/$UPGRADE_FILE -b 16384
    fi
    ret=$?
    if [ $ret -ne 0 ] ; then
        echo "`Timestamp` PDRI TFTP image download for file $UPGRADE_FILE failed."
    else
        echo "`Timestamp` $UPGRADE_FILE TFTP Download Completed.!"
    fi
    return $ret
}

interrupt_download()
{
     echo "Download is interrupted due to the PowerState changed to ON"
     if [ -f $CURL_PID_FILE ]; then
        kill -9 $CurlPid
        rm -rf "$CURL_PID_FILE"
     fi

     rm -rf "$FWDNLD_PID_FILE"

     if [ "$PID_PWRSTATE" != "" ]; then
        kill -9 $PID_PWRSTATE
     fi

    #Notify Maintenance Manager, So that Maintenance thread can proceed  to next script.
    eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR

     exit
}

if [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
interrupt_download_onabort()
{
     echo "Download is interrupted due to the maintenance abort"
     if [ -f $CURL_PID_FILE ]; then
        kill -9 $CurlPid
        rm -rf "$CURL_PID_FILE"
     fi

     rm -rf "$FWDNLD_PID_FILE"
     rm -rf  /tmp/DIFD.pid

    eventSender "FirmwareStateEvent" $FW_STATE_UNINITIALIZED

    sh /lib/rdk/maintenanceTrapEventNotifier.sh 2 &

    trap - SIGABRT

     exit
}
fi
getNewCronTime ()
{
   now=$(date +"%T")

   NewCronHr=$(echo $now | cut -d':' -f1)
   NewCronMin=$(echo $now | cut -d':' -f2)
   Sec=$(echo $now | cut -d':' -f3)


   if [ $Sec -gt 29 ]; then
      NewCronMin=`expr $NewCronMin + 1`
   fi

   NewCronMin=`expr $NewCronMin + $1`
   
   while [ $NewCronMin -gt 59 ]
   do
      NewCronMin=`expr $NewCronMin - 60`
      NewCronHr=`expr $NewCronHr + 1`
      if [ $NewCronHr -gt 23 ]; then
        NewCronHr=0
      fi
   done
}
##
## Are We Delaying the FW image download to the box
##
isDelayFWDownloadActive ()
{
    echo  "`Timestamp` Reboot Immed. : $cloudImmediateRebootFlag"

    if [ "$DelayDownloadXconf" == "1" ]; then
        echo "`Timestamp` Device configured with download delay of $DelayDownloadXconf minute."
    else
        if [ "$DelayDownloadXconf" == "" ]; then
            DelayDownloadXconf=0
        fi
        echo "`Timestamp` Device configured with download delay of $DelayDownloadXconf minutes."
    fi


        if [ $DelayDownloadXconf -gt 0 ]; then

            echo "`Timestamp` Modify The Cron Table.  Trigger Type : $triggerType"
            # Remove any old Delay Image Upload Cron Jobs
            sh /lib/rdk/cronjobs_update.sh "remove" "deviceInitiatedFWDnld.sh"

            if [ $triggerType -ne 5 ]; then
               getNewCronTime $DelayDownloadXconf
               echo "`Timestamp` Scheduling Cron for deviceInitiatedFWDnld.sh as a part of DelayDownload."
               echo "`Timestamp` Delay Cron Job Time : $NewCronHr Hrs. $NewCronMin Mins."
               sh /lib/rdk/cronjobs_update.sh "add" "deviceInitiatedFWDnld.sh" "$NewCronMin $NewCronHr * * * /bin/sh $RDK_PATH/deviceInitiatedFWDnld.sh 0 5 >> /opt/logs/swupdate.log 2>&1"
            fi

            if [ $triggerType -ne 5 ]; then
               echo "`Timestamp` Exit for this Trigger Type : $triggerType"
               updateUpgradeFlag remove
               rm -f $FILENAME $HTTP_CODE
               # we gracefully exit from this script
               # so that MM wont hung and send the event as error
               if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue"  ];then
                   echo "`Timestamp` Sending event to Maintenance Plugin with Error before exit"
                   eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
               fi
               exit 0
            fi
        fi
}
##
## trigger image download to the box
##
imageDownloadToLocalServer ()
{
    echo "`Timestamp` Triggering the Image Download ..."
    UPGRADE_LOCATION=$1
    UPGRADE_FILE=$2
    REBOOT_FLAG=$3
    UPGRADE_PROTO=$4
    PDRI_UPGRADE=$5
    echo "`Timestamp` Upgrade Location = $UPGRADE_LOCATION"
    echo "`Timestamp` Upgrade File = $UPGRADE_FILE"
    echo "`Timestamp` Upgrade Reboot Flag = $REBOOT_FLAG"
    echo "`Timestamp` Upgrade protocol = $UPGRADE_PROTO"
    echo "`Timestamp` PDRI Flag  = $PDRI_UPGRADE"
     
    eventManager $ImageDwldEvent $IMAGE_FWDNLD_UNINITIALIZED
    if [ ! -d $DIFW_PATH ]; then
        mkdir -p $DIFW_PATH
    fi
    cd $DIFW_PATH

    #Delete already existing files from download folder
    model_num=$(getModel)
    if [ "x$PDRI_UPGRADE" == "xpdri" ]; then
        rm $model_num*PDRI*.bin
        echo "`Timestamp` PDRI Download in Progress for $UPGRADE_FILE "
    else
        rm $model_num*.bin
        echo "`Timestamp` PCI Download in Progress for $UPGRADE_FILE "
    fi

    status=$DOWNLOAD_IN_PROGRESS
    if [ "$DEVICE_TYPE" != "mediaclient" ]; then
        status="ESTB in progress"        
    fi     


    updateFWDownloadStatus "$cloudProto" "$status" "$cloudImmediateRebootFlag" "" "$dnldVersion" "$cloudFWFile" "$runtime" "Downloading" "$DelayDownloadXconf"
    eventManager $FirmwareStateEvent $FW_STATE_DOWNLOADING 
    eventManager $ImageDwldEvent $IMAGE_FWDNLD_DOWNLOAD_INPROGRESS

    #Set FirmwareDownloadStartedNotification before starting of firmware download
    if [ "${isMmgbleNotifyEnabled}" = "true" ]; then
        current_time=`date +%s`
        echo "current_time calculated as $current_time"
        tr181 -s -v $current_time  Device.DeviceInfo.X_RDKCENTRAL-COM_xOpsDeviceMgmt.RPC.FirmwareDownloadStartedNotification
        echo "FirmwareDownloadStartedNotification SET succeeded"
    fi

    isDelayFWDownloadActive

    if [ $UPGRADE_PROTO -eq 1 ]; then
        tftpDownload
        ret=$?
    elif [ $UPGRADE_PROTO -eq 2 ]; then
        # Change to support whether full http URL
        imageHTTPURL="$UPGRADE_LOCATION/$UPGRADE_FILE"  
        echo  "`Timestamp` IMAGE URL= $imageHTTPURL"
        echo "$imageHTTPURL" > $DnldURLvalue
        httpDownload 
        ret=$?
    fi

    http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
    if [ $ret -ne 0 ] || [ "$http_code" != "200" ]; then
        updateUpgradeFlag remove
        failureReason="ESTB Download Failure"
        if [ "$DEVICE_TYPE" == "mediaclient" ]; then
            if [ "x$http_code" = "x000" ]; then
               failureReason="Image Download Failed - Unable to connect"
            elif [ "x$http_code" = "x404" ]; then
               failureReason="Image Download Failed - Server not Found"
            elif [[ "$http_code" -ge 500 ]] && [[ "$http_code" -le 511 ]]; then
               failureReason="Image Download Failed - Error response from server"
            else
               failureReason="Image Download Failed - Unknown"
            fi
        fi    
        updateFWDownloadStatus "$cloudProto" "Failure" "$cloudImmediateRebootFlag" "$failureReason" "$dnldVersion" "$cloudFWFile" "$runtime" "Failed" "$DelayDownloadXconf"
        eventManager $FirmwareStateEvent $FW_STATE_FAILED
        eventManager $ImageDwldEvent $IMAGE_FWDNLD_DOWNLOAD_FAILED

        if [ "${isMmgbleNotifyEnabled}" = "true" ]; then
            #Set FirmwareDownloadCompletedNotification after firmware download
            tr181 -s -v false  Device.DeviceInfo.X_RDKCENTRAL-COM_xOpsDeviceMgmt.RPC.FirmwareDownloadCompletedNotification
            echo "FirmwareDownloadCompletedNotification SET to false succeeded"
         fi 
        return $ret
    elif [ -f "$UPGRADE_FILE" ]; then
        echo "`Timestamp` $UPGRADE_FILE Local Image Download Completed using HTTPS $TLS protocol!"
        if [ "$CPU_ARCH" == "x86" ]; then
            status="Triggered ECM download"
        elif [ "$DEVICE_TYPE" == "mediaclient" ]; then
            status=$UPGRADE_IN_PROGRESS
        else
            status="Download complete"
        fi
        updateFWDownloadStatus "$cloudProto" "$status" "$cloudImmediateRebootFlag" "" "$dnldVersion" "$cloudFWFile" "$runtime" "Download complete" "$DelayDownloadXconf"
        eventManager $FirmwareStateEvent $FW_STATE_DOWNLOAD_COMPLETE
        if [ "${isMmgbleNotifyEnabled}" = "true" ]; then
            #Set FirmwareDownloadCompletedNotification after firmware download
            tr181 -s -v true  Device.DeviceInfo.X_RDKCENTRAL-COM_xOpsDeviceMgmt.RPC.FirmwareDownloadCompletedNotification
            echo "FirmwareDownloadCompletedNotification SET to true succeeded"
        fi
        if [ "$CPU_ARCH" != "x86" ]; then
            eventManager $ImageDwldEvent $IMAGE_FWDNLD_DOWNLOAD_COMPLETE
        fi    
        filesize=`ls -l $UPGRADE_FILE |  awk '{ print $5}'`
        echo "`Timestamp` Downloaded $UPGRADE_FILE of size $filesize"
    fi    
    return $ret
}


updateSecurityStage () {
	if [ "$DEVICE_NAME" = "PLATCO" ] && [ ! -f $STAGE2LOCKFILE ]; then
		# set the "deviceStage" to right stage (stage2)
		curl -H "Authorization: Bearer `WPEFrameworkSecurityUtility | cut -d '"' -f 4`" --header "Content-Type: application/json" -X PUT http://127.0.0.1:9998/Service/Controller/Activate/org.rdk.FactoryProtect.1
		curl -H "Authorization: Bearer `WPEFrameworkSecurityUtility | cut -d '"' -f 4`" --header "Content-Type: application/json" -d '{"jsonrpc":"2.0", "id":3, "method":"org.rdk.FactoryProtect.1.setManufacturerData", "params":{ "key":"deviceStage", "value":"stage2" }}' http://127.0.0.1:9998/jsonrpc
		touch $STAGE2LOCKFILE
	fi
}
postFlash () {
    updateSecurityStage
    updateFWDownloadStatus "$cloudProto" "Success" "$cloudImmediateRebootFlag" "" "$dnldVersion" "$cloudFWFile" "$runtime" "Validation complete" "$DelayDownloadXconf"
    eventManager $FirmwareStateEvent $FW_STATE_VALIDATION_COMPLETE
    eventManager $ImageDwldEvent $IMAGE_FWDNLD_FLASH_COMPLETE
    sleep 5
    sync
    eventManager $FirmwareStateEvent $FW_STATE_PREPARING_TO_REBOOT
    
    sed -i 's/FwUpdateState|.*/FwUpdateState|Preparing to reboot/g' $STATUS_FILE

    if [ "x$PDRI_UPGRADE" == "xpdri" ]; then
        echo "Reboot Not Needed after PDRI Upgrade..!"
    else  
       if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
         then 
            echo "$UPGRADE_FILE" > /opt/cdl_flashed_file_name
	    eventSender "MaintenanceMGR" $MAINT_REBOOT_REQUIRED
       else    
             echo "$UPGRADE_FILE" > /opt/cdl_flashed_file_name
             if [ $REBOOT_FLAG -eq 1 ]; then
                 echo "Download is complete. Rebooting the box now...\n"
                 echo "Trigger RebootPendingNotification in background"
                 if [ "${isMmgbleNotifyEnabled}" = "true" ]; then
                      Trigger_RebootPendingNotify &
                 fi
                 if [ $redflagset -eq 1 ]; then
                      stateRedlog "state red firmware updated rebooting"
                      unsetStateRed
                 fi
                 echo "sleep for $REBOOT_PENDING_DELAY sec to send reboot pending notification"
                 sleep $REBOOT_PENDING_DELAY
                 sh /rebootNow.sh -s UpgradeReboot_"`basename $0`" -o "Rebooting the box after Firmware Image Upgrade..."
             fi
        fi    
    fi
} 

invokeImageFlasher () {
    echo "`Timestamp` Starting Image Flashing ..."
    ret=0
    UPGRADE_SERVER=$1
    UPGRADE_FILE=$2
    REBOOT_FLAG=$3
    UPGRADE_PROTO=$4
    PDRI_UPGRADE=$5
    echo "`Timestamp` Upgrade Server = $UPGRADE_SERVER "
    echo "`Timestamp` Upgrade File = $UPGRADE_FILE "
    echo "`Timestamp` Reboot Flag = $REBOOT_FLAG "
    echo "`Timestamp` Upgrade protocol = $UPGRADE_PROTO "
    echo "`Timestamp` PDRI Upgrade = $PDRI_UPGRADE "

    if [ "x$PDRI_UPGRADE" == "xpdri" ] ; then
        echo "`Timestamp` Updating PDRI image with  $UPGRADE_FILE "
    fi

    if [ "$DEVICE_TYPE" == "mediaclient" ]; then
        eventManager $ImageDwldEvent $IMAGE_FWDNLD_FLASH_INPROGRESS
    fi

    if [ -f /lib/rdk/imageFlasher.sh ];then
        /lib/rdk/imageFlasher.sh $UPGRADE_PROTO $UPGRADE_SERVER $DIFW_PATH $UPGRADE_FILE $REBOOT_FLAG $PDRI_UPGRADE
        ret=$?
    else
        echo "imageFlasher.sh is missing"
    fi

    if [ $ret -ne 0 ]; then
        echo "`Timestamp` Image Flashing failed"
        if [ "$DEVICE_TYPE" != "mediaclient" ]; then
            failureReason="RCDL Upgrade Failed"
            if [ "$CPU_ARCH" == "x86" ]; then
                failureReason="ECM trigger failed"
            fi    
        else
            failureReason="Failed in flash write"
            eventManager $ImageDwldEvent $IMAGE_FWDNLD_FLASH_FAILED
        fi
        updateFWDownloadStatus "$cloudProto" "Failure" "$cloudImmediateRebootFlag" "$failureReason" "$dnldVersion" "$cloudFWFile" "$runtime" "Failed" "$DelayDownloadXconf"
        eventManager $FirmwareStateEvent $FW_STATE_FAILED
        updateUpgradeFlag "remove"
    elif [ "$DEVICE_TYPE" == "mediaclient" ]; then
        echo "`Timestamp` Image Flashing is success"
        postFlash
    fi
    if [ "$DEVICE_TYPE" == "mediaclient" ]; then
        rm -rf $DIFW_PATH/$UPGRADE_FILE
        updateUpgradeFlag "remove"
    fi    
    return $ret
}     

## get Server URL
getServURL()
{
    buildType=$(getBuildType)

#High Priority State Red recovery RDK-30717
#If in state red other use cases are ignored
    isInStateRed
    redflagset=$?
    if [ $redflagset -eq 1 ]; then
        if [ -f $PERSISTENT_PATH/stateredrecovry.conf ] && [ $buildType != "prod" ] ; then
            urlString=`grep -v '^[[:space:]]*#' $PERSISTENT_PATH/stateredrecovry.conf`
            if [ $? -ne 0 ]; then
                urlString=""
            else
                echo $urlString
                return
            fi
        fi
        CLOUD_URL=`tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Bootstrap.XconfRecoveryUrl 2>&1 > /dev/null`
        echo $CLOUD_URL
        return
    fi

    if [ -f $PERSISTENT_PATH/swupdate.conf ] && [ $buildType != "prod" ] ; then
        urlString=`grep -v '^[[:space:]]*#' $PERSISTENT_PATH/swupdate.conf`
        if [ $? -ne 0 ]; then
            urlString=""
        else
            echo $urlString
            return
        fi
    fi

    urlString=`tr181 -D Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.FWUpdate.AutoExcluded.XconfUrl 2>&1 > /dev/null`
    if [ "$urlString" ] && [ $buildType != "prod" ] ; then
        CLOUD_URL=$urlString
    else
        case $buildType in
        "qa" )
            # QA server URL
            CLOUD_URL="$DEVXCONF_URL";;
        * )
            CLOUD_URL="https://${XCONF_URL}/xconf/swu/stb/";;   # Pdn server URL
        esac

        urlString=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Bootstrap.XconfUrl 2>&1 > /dev/null)
        if [ "$urlString" ]; then
            CLOUD_URL="$urlString/xconf/swu/stb"
        fi
    fi
    echo $CLOUD_URL
}

getRequestType()
{
    if [ "$1" == $XCONF_URL ]; then
        request_type=2
    elif [ "$1" == $CIXCONF_URL ]; then
        request_type=4
    else
        request_type=0
    fi
    return $request_type
}

checkAndTriggerPDRIUpgrade () {
    rebootFlag=1
    if [ "$cloudImmediateRebootFlag" = "false" ]; then
        rebootFlag=0   
    fi
    myPdriFile=`echo $myPdriFile | tr '[A-Z]' '[a-z]' | sed -e "s/.bin//g"`
    dnldPdriFile=`echo $dnldPdriFile | sed -e "s/.bin//g"`
    isSamePDRIfw=1
    echo "`Timestamp` myPdriFile : $myPdriFile    dnldPdriFile : $dnldPdriFile "
    signedPdri=$myPdriFile"-signed"
    if [ "$myPdriFile" == "$dnldPdriFile" ] || [ "$signedPdri" == "$dnldPdriFile" ]; then
        isSamePDRIfw=0
    fi
    # Check if we have same PDRI version or not
    if [ $isSamePDRIfw -ne 0 ] ; then
        #Download the image using the existing function
        if [ "$cloudProto" = "http" ] ; then
            protocol=2
        else
            protocol=1
            addressType=$(getaddressType)
            cloudFWLocation=$ipv4cloudFWLocation
            if [ "$addressType" == "ipv6" ] ; then
                cloudFWLocation=$ipv6cloudFWLocation
            fi                
        fi
        if [[ "$cloudPDRIVersion" != *.bin ]]; then
            cloudPDRIVersion=$cloudPDRIVersion.bin
        fi
        imageDownloadToLocalServer $cloudFWLocation $cloudPDRIVersion $rebootFlag $protocol "pdri"
        ret=$?
        if [ $ret -eq 0 ] && [ "$http_code" = "200" ]; then
            invokeImageFlasher $cloudFWLocation $cloudPDRIVersion $rebootFlag $protocol "pdri"
            ret=$?
        fi

        if [[ "$cloudPDRIVersion" != *.bin ]]; then
            cloudPDRIVersion=$cloudPDRIVersion.bin
        fi

        if [ $pci_upgrade -eq 1 ];then
            echo "`Timestamp` Adding a sleep of 30secs to avoid the PCI PDRI race condition during flashing"
            sleep 30
        fi

        if [ $ret -eq 0 ]; then
            echo "`Timestamp` PDRI image upgrade successful."
        else
            echo "`Timestamp` PDRI image upgrade failure !!!"
            t2CountNotify "SYST_ERR_PDRIUpg_failure"
        fi
    else
        echo "`Timestamp` PDRI version of the active image and the image to be upgraded are the same. No upgrade required."
    fi
    return $ret
}

triggerPCIUpgrade () {
    if [ "$cloudProto" = "http" ] ; then
        protocol=2
    else
        addressType=$(getaddressType)
        if [ "$addressType" == "ipv6" ];then
            cloudFWLocation=$ipv6cloudFWLocation
        fi
        protocol=1
    fi

    # check whether any upgrade is in progress
    if [ -f $HTTP_CDL_FLAG ] || [ -f $SNMP_CDL_FLAG ] || [ -f $ECM_CDL_FLAG ]; then
         echo "[$0]: Exiting from DEVICE INITIATED HTTP CDL"
         echo "[$0]: Another upgrade is in progress"
         if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
         then
             eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
         fi
         exit 0
    fi

    if [ -f /lib/rdk/logMilestone.sh ];then
        sh /lib/rdk/logMilestone.sh "FWDNLD_STARTED"
    fi
    resp=1
    updateUpgradeFlag "create"
    if [ "$DEVICE_TYPE" != "mediaclient" ] && [ $protocol -eq 1 ]; then
        updateFWDownloadStatus "$cloudProto" "Triggered ECM download" "$cloudImmediateRebootFlag" "" "$dnldVersion" "$cloudFWFile" "$runtime" "" "$DelayDownloadXconf"
        resp=0     
    else
        imageDownloadToLocalServer $cloudFWLocation $cloudFWFile $rebootFlag $protocol
        resp=$?
    fi
    if [ $resp -eq 0 ] && [ "$http_code" = "200" ]; then
        invokeImageFlasher $cloudFWLocation $cloudFWFile $rebootFlag $protocol
        resp=$?
    fi  
     
    echo "`Timestamp` upgrade method returned $resp"
    if [ $resp != 0 ] ; then
        if [ -f /lib/rdk/logMilestone.sh ];then
            sh /lib/rdk/logMilestone.sh "FWDNLD_FAILED"
        fi
        echo "`Timestamp` doCDL failed"   
        ret=1
    else
        if [ -f /lib/rdk/logMilestone.sh ];then
            sh /lib/rdk/logMilestone.sh "FWDNLD_COMPLETED"
        fi
        echo "`Timestamp` doCDL success."
        ret=0
    fi
    return $ret
}

checkForValidPCIUpgrade () {
    upgrade=0

    echo "Xconf image/PDRI configuration Check"
    wrongConfigCheck=`echo $dnldFile | grep "_PDRI_"`
    if [ "$wrongConfigCheck" ];then 
        echo "PDRI image is wrongly configured as Cloud Firmware Value"
    fi 
    rebootFlag=1
    if [ "$cloudImmediateRebootFlag" = "false" ]; then
        rebootFlag=0
    fi

    # Adding the check to perform upgrade when $myFWFile is empty for both app triggered and maintainene triggered reboot
    if [ $triggerType -eq 1 ] || [ $triggerType -eq 4 ]; then
        if [ -z "$myFWFile" ] || [ -z "$lastDnldFile" ]; then
            echo "Unable to fetch current running image file name or last download file"
            if [ "$myFWVersion" != "$cloudFWVersion" ]; then
                echo "Firmware versions are different myFWVersion : $myFWVersion cloudFWVersion : $cloudFWVersion"
                upgrade=1
            fi
        fi
        if [ "$myFWFile" != "$dnldFile" ] && [ ! "$wrongConfigCheck" ]; then
            #For DIFD triggerred as part of bootup compare image name with currently_running_image_name
            #cdl_flashed_file_name is not significant here
            pci_upgrade=1
            return
        fi
    fi

    if [ $upgrade -eq 1 ] && [ ! "$wrongConfigCheck" ]; then
        echo "`Timestamp` Error identified with image file comparison !!! Proceeding with firmware version check."
        # In error conditions relay only on firmware version for image upgrade
        if [ "$myFWVersion" != "$cloudFWVersion" ]; then
            pci_upgrade=1
        fi
    elif [ "$myFWFile" != "$dnldFile" ] && [ ! "$wrongConfigCheck" ] || [ $upgrade -eq 1 ] && [ ! "$wrongConfigCheck" ]; then
        if [ "$lastDnldFile" != "$dnldFile" ] || [ $upgrade -eq 1 ]; then
            #pci upgrade is true
            pci_upgrade=1
        else
            echo "`Timestamp` FW version of the standby image and the image to be upgraded are the same. No upgrade required."
            t2CountNotify "fwupgrade_failed"
            updateFWDownloadStatus "$cloudProto" "No upgrade needed" "$cloudImmediateRebootFlag" "Versions Match" "$dnldVersion" "$cloudFWFile" "$runtime" "No upgrade needed" "$DelayDownloadXconf"
            eventManager $FirmwareStateEvent $FW_STATE_FAILED
            updateUpgradeFlag "remove"
        fi

    else
        echo "`Timestamp` FW version of the active image and the image to be upgraded are the same. No upgrade required."
        updateFWDownloadStatus "$cloudProto" "No upgrade needed" "$cloudImmediateRebootFlag" "Versions Match" "$dnldVersion" "$cloudFWFile" "$runtime" "No upgrade needed" "$DelayDownloadXconf"
        eventManager $FirmwareStateEvent $FW_STATE_FAILED
        updateUpgradeFlag "remove"
    fi
}

checkForUpgrades () {
    ret=0

    # PCI Upgrades
    pci_upgrade=0
    if [ $pci_upgrade_status -ne 0 ]; then
        pci_upgrade_status=0  
        if [[ ! -n "$cloudFWVersion" ]] ; then
            echo "`Timestamp` cloudFWVersion is empty. Do Nothing"
            updateFWDownloadStatus "$cloudProto" "Failure" "$cloudImmediateRebootFlag" "Cloud FW Version is empty" "$dnldVersion" "$cloudFWFile" "$runtime" "Failed" "$DelayDownloadXconf"
            eventManager $FirmwareStateEvent $FW_STATE_FAILED
        else
            checkForValidPCIUpgrade
            if [ $pci_upgrade -eq 1 ]; then
                if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
                then  
                    eventSender "MaintenanceMGR" $MAINT_CRITICAL_UPDATE
                    isCriticalUpdate=true 
                fi 
                triggerPCIUpgrade
                pci_upgrade_status=$?
            fi
        fi
    fi

    # PDRI Upgrades
    if [ $pdri_upgrade_status -ne 0 ]; then
        pdri_upgrade_status=0
        if [ "$PDRI_ENABLED" == "true" ]; then
            # Do not upgrade if Reboot flag is True && pci_upgrade is True
            if [ "$cloudImmediateRebootFlag" = "true" ] && [ $pci_upgrade -eq 1 ] ; then
                echo "`Timestamp` cloudImmediateRebootFlag is $cloudImmediateRebootFlag , PCI Upgrade is required . Skipping PDRI upgrade check ... "
                return $ret
            else
                echo "`Timestamp` cloudImmediateRebootFlag is $cloudImmediateRebootFlag. Starting PDRI upgrade check ... "
            fi
            if [ "$wrongConfigCheck" -a ! "$cloudPDRIVersion" ];then
                cloudPDRIVersion=$cloudFWVersion
            fi
            #All PCI related upgrades are done,Start with PDRI
            if [[ ! -n "$cloudPDRIVersion" ]] ; then
                echo "`Timestamp` cloudPDRIfile is empty. Do Nothing"
            else
                disableStatsUpdate="yes"
                checkAndTriggerPDRIUpgrade
                pdri_upgrade_status=$?
                disableStatsUpdate="no"
            fi
        fi    
    fi

    # Peripheral Upgrades
    if [ $peripheral_upgrade_status -ne 0 ]; then
        peripheral_upgrade_status=0
        if [ -f /etc/os-release ] && [ "$peripheralFirmwares" != "" ] && [ "$cloudProto" == "http" ]; then   
            getPeripheralFirmwares "$cloudFWLocation" "$peripheralFirmwares" "$UseCodebig"
            peripheral_upgrade_status=$?
        else
            echo "Skipping Peripheral Download"
        fi
    fi
   
    if [ $pci_upgrade_status -ne 0 ] || [ $pdri_upgrade_status -ne 0 ] || [ $peripheral_upgrade_status -ne 0 ]; then   
        ret=1
    fi
    return $ret
}

processJsonResponse()
{
    FILENAME=$1
    OUTPUT="$PERSISTENT_PATH/output.txt"
    OUTPUT1=`cat $FILENAME | tr -d '\n' | sed 's/[{}]//g' | awk  '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed -r 's/\"\:(true)($)/\|true/gI' | sed -r 's/\"\:(false)($)/\|false/gI' | sed -r 's/\"\:(null)($)/\|\1/gI' | sed -r 's/\"\:([0-9]+)($)/\|\1/g' | sed 's/[\,]/ /g' | sed 's/\"//g' > $OUTPUT`
    echo OUTPUT1 : $OUTPUT1

    cloudFWFile=`grep firmwareFilename $OUTPUT | cut -d \| -f2`
    cloudFWLocation=`grep firmwareLocation $OUTPUT | cut -d \| -f2 | tr -d ' '`
    cloudFWLocation=`echo $cloudFWLocation | sed "s/http:/https:/g"`
    echo "$cloudFWLocation" > /tmp/.xconfssrdownloadurl
    ipv4cloudFWLocation=$cloudFWLocation
    ipv6cloudFWLocation=`grep ipv6FirmwareLocation  $OUTPUT | cut -d \| -f2 | tr -d ' '`
    ipv6cloudFWLocation=`echo $ipv6cloudFWLocation | sed "s/http:/https:/g"`
    cloudFWVersion=`grep firmwareVersion $OUTPUT | cut -d \| -f2`
    DelayDownloadXconf=`grep delayDownload $OUTPUT | cut -d \| -f2`
    cloudProto=`grep firmwareDownloadProtocol $OUTPUT | cut -d \| -f2`          # Get download protocol to be used
    cloudImmediateRebootFlag=`grep rebootImmediately $OUTPUT | cut -d \| -f2`    # immediate reboot flag
    peripheralFirmwares=`grep remCtrl $OUTPUT | cut -d "|" -f2 | tr '\n' ','`    # peripheral firmwares
    dlCertBundle=$($JSONQUERY -f $FILENAME -p dlCertBundle)

    echo "`Timestamp` cloudFWFile: $cloudFWFile"
    echo "`Timestamp` cloudFWLocation: $cloudFWLocation"
    echo "`Timestamp` ipv6cloudFWLocation: $ipv6cloudFWLocation"
    echo "`Timestamp` cloudFWVersion: $cloudFWVersion"
    echo "`Timestamp` cloudDelayDownload: $DelayDownloadXconf"
    echo "`Timestamp` cloudProto: $cloudProto"
    echo "`Timestamp` cloudImmediateRebootFlag: $cloudImmediateRebootFlag"
    echo "`Timestamp` peripheralFirmwares: $peripheralFirmwares"
    echo "`Timestamp` dlCertBundle: $dlCertBundle"

    # Check if xconf returned any bundles to update
    # If so, trigger /etc/rdm/rdmBundleMgr.sh to process it
    if [ -n "$dlCertBundle" ]; then
	 echo "`Timestamp` Calling /etc/rdm/rdmBundleMgr.sh to process bundle update"
	 (sh /etc/rdm/rdmBundleMgr.sh "$dlCertBundle" "$cloudFWLocation" >> $LOG_PATH/rdm_status.log 2>&1) &
	 echo "`Timestamp` /etc/rdm/rdmBundleMgr.sh started in background"
    fi

    cloudfile_model=`echo $cloudFWFile | cut -d '_' -f1`
    if [[ "$cloudfile_model" != *"$MODEL_NUM"* ]]; then
        echo "`Timestamp` Image configured is not of model $MODEL_NUM.. Skipping the upgrade"
        echo "`Timestamp` Exiting from Image Upgrade process..!"
        updateFWDownloadStatus "$cloudProto" "Failure" "$cloudImmediateRebootFlag" "Cloud FW Version is invalid" "$cloudFWVersion" "$cloudFWFile" "$runtime" "Failed" "$DelayDownloadXconf"
        eventManager $FirmwareStateEvent $FW_STATE_FAILED
        if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
        then
             eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
        fi
        rm -f $FILENAME $HTTP_CODE
        exit 0
    fi

    if [ "$PDRI_ENABLED" = "true" ] ; then   #get PDRI version from the cloud
        cloudPDRIVersion=`grep additionalFwVerInfo $OUTPUT | cut -d \| -f2 | tr -d ' '`
        echo "`Timestamp` cloudPDRIVersion: $cloudPDRIVersion"
        pdriVersion=`echo $cloudPDRIVersion | tr '[A-Z]' '[a-z]'`
        dnldPdriFile=$pdriVersion  # This doesn't have the file extension (.bin)
        #this one is the device PDRI;Global one
        myPdriFile=$pdriFwVerInfo
    fi

    myPartnerID=$(getPartnerId)
    myPartnerID=`echo $myPartnerID | tr '[A-Z]' '[a-z]'`
    echo "`Timestamp` myPartnerID = $myPartnerID"

    myFWVersion=$(getFWVersion)
    currentVersion=$myFWVersion
    myFWVersion=`echo $myFWVersion | tr '[A-Z]' '[a-z]'`
    dnldVersion=$cloudFWVersion
    cloudFWVersion=`echo $cloudFWVersion | tr '[A-Z]' '[a-z]'`
    dnldFile=`echo $cloudFWFile | tr '[A-Z]' '[a-z]'`

    if [ -f /opt/cdl_flashed_file_name ]; then
        lastDnldFile=`cat /opt/cdl_flashed_file_name`
        lastDnldFileName=$lastDnldFile
        lastDnldFile=`echo $lastDnldFile | tr '[A-Z]' '[a-z]'`
    fi
    if [ -f /tmp/currently_running_image_name ]; then
        myFWFile=`cat /tmp/currently_running_image_name`
        currentFile=$myFWFile
        myFWFile=`echo $myFWFile | tr '[A-Z]' '[a-z]'`
    fi

    echo "`Timestamp` myFWVersion = $myFWVersion"
    echo "`Timestamp` myFWFile = $myFWFile"
    echo "`Timestamp` lastDnldFile: $lastDnldFile"
    echo "`Timestamp` cloudFWVersion: $cloudFWVersion"
    echo "`Timestamp` cloudFWFile: $dnldFile"

    checkForUpgrades
    return $?
}

exitForXconf404response () {
    echo "`Timestamp` Received HTTPS 404 Response from Xconf Server. Retry logic not needed"
    echo "`Timestamp` Creating /tmp/.xconfssrdownloadurl with 404 response from Xconf"
    echo "404" > /tmp/.xconfssrdownloadurl

    unsetStateRed

    echo "`Timestamp` Exiting from Image Upgrade process..!"
    updateFWDownloadStatus "" "Failure" "" "Invalid Request" "" "" "$runtime" "Failed" "$DelayDownloadXconf"
    eventManager $FirmwareStateEvent $FW_STATE_FAILED
    if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
    then
             eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
    fi
    rm -f $FILENAME $HTTP_CODE
    exit 0
}

getPDRIVersion () {
    if [ -f /usr/bin/mfr_util ]; then
        pdriVersion=`/usr/bin/mfr_util --PDRIVersion`
        echo "$pdriVersion" | grep -i 'failed' >  /dev/null
        if [ $? -eq 0 ] ; then
            echo "`Timestamp` PDRI version Retrieving Failed ..."
        else
            #copy to global variable
            pdriFwVerInfo=$pdriVersion
            echo "`Timestamp` PDRI Version = $pdriFwVerInfo"
        fi
    else
        echo "`Timestamp` mfr_utility Not found. No P-DRI Upgrade !!"
    fi
}

createJsonString () {
    #Check if PDRI is supported or not
    if [ "$PDRI_ENABLED" == "true" ] ; then
        getPDRIVersion
    else
        echo "`Timestamp` P-DRI Upgrade Unsupported !!"
    fi

    remoteInfo=""
    if [ -f /etc/os-release ]; then
        echo "Getting peripheral device firmware info"
        remoteInfo=$(getRemoteInfo)
    fi        
    model=$(getModel)
    if [ "$DEVICE_TYPE" == "mediaclient" ]; then
        estbMac=$(getEstbMacAddress)
    else
        estbMac=$(getMacAddress)
    fi    

    partnerId=$(getPartnerId)
    if [ "$partnerId" != "" ]; then    
        ACTIVATE_FLAG='&activationInProgress=false'
    else
        ACTIVATE_FLAG='&activationInProgress=true'
    fi
    
    #Get already Installed Bundle list
    instBundles=$(getInstalledBundleList)
     
    #Included additionalFwVerInfo and partnerId
    if [ "$(getModel)" = "RPI" ]; then
    JSONSTR='eStbMac='$(getEstbMacAddress)'&firmwareVersion='$(getFWVersion)'&env='$(getBuildType)'&model='$BOX_MODEL'&localtime='$(getLocalTime)'&timezone='EST05EDT''$CAPABILITIES''
    else
    JSONSTR='eStbMac='$estbMac'&firmwareVersion='$(getFWVersion)'&additionalFwVerInfo='$pdriFwVerInfo''$remoteInfo'&env='$(getBuildType)'&model='$model'&partnerId='$(getPartnerId)'&accountId='$(getAccountId)'&experience='$(getExperience)'&serial='$(getSerialNumber)'&localtime='$(getLocalTime)'&dlCertBundle='$instBundles'&timezone='$zoneValue''$ACTIVATE_FLAG''$CAPABILITIES''
    fi

    isInStateRed
    stateRed=$?
    if [ "0x$stateRed" == "0x1" ]; then
    JSONSTR=$JSONSTR'&recovery="true"'
    fi
}


CheckIPRoute()
{
    ipconf=0
    IPRouteCheck_count=0
    echo "`Timestamp` CheckIPRoute Waiting for Route Config $ROUTE_FLAG file"
    while [ ! -f $ROUTE_FLAG ]
    do
        sleep 15
        let "IPRouteCheck_count+=1"
        if [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
        then
            if [ $IPRouteCheck_count == $ROUTE_FLAG_MAX_CHECK ]
            then
                echo " Maintenance cannot wait in a indefinit loop - So exiting !!"
                break;
            fi
        fi
    done

    if [ -f $ROUTE_FLAG ]; then
        echo "`Timestamp` CheckIPRoute Received Route Config $ROUTE_FLAG file"
        if [ -f $GATEWAYIP_FILE ]; then
            echo "`Timestamp` CheckIPRoute Ensure ping is working on the default router Link Local IP"
            while IFS= read -r line; do
                IPMODE=`echo $line | awk -F " " '{print $1}'`
                IPADDR=`echo $line | awk -F " " '{print $2}'`
                if [ "$IPMODE" = "$AF_INET" ]; then
                    $PING -4 -c 3 $IPADDR  > /dev/null
                    if [ $? -eq 0 ]; then
                       echo "`Timestamp` CheckIPRoute ping to link local address $IPADDR success"
                       ipconf=1
                    fi
                elif [ "$IPMODE" = "$AF_INET6" ]; then
                   $PING -6 -c 3 "$IPADDR"  > /dev/null
                   if [ $? -eq 0 ]; then
                      echo "`Timestamp` CheckIPRoute ping to link local address $IPADDR success"
                      ipconf=1
                   fi
                fi
            done < $GATEWAYIP_FILE
        else
            echo "`Timestamp` CheckIPRoute GatewayIP: $GATEWAYIP_FILE file not found"
        fi
    else
        echo "`Timestamp` CheckIPRoute Route Config: $ROUTE_FLAG file not found"
    fi

    return $ipconf
}

checkDNS_NameServers()
{
    dnsconf=0
    if  [ -f "$RESOLV_FILE" ] && [[ $(grep "nameserver" $RESOLV_FILE) ]]; then
        DNSSERVER=`cat $RESOLV_FILE | grep "nameserver"`
        dnsconf=1
        echo "`Timestamp` checkDNS_NameServers List of nameservers received in $RESOLV_FILE:${DNSSERVER}"
    else
        dnsconf=0
        echo "`Timestamp` checkDNS_NameServers DNS $RESOLV_FILE file missing or nameservers not found"
    fi
    
    return $dnsconf
}

sendXCONFTLSRequest () {

    ret=1
    http_code="000"
    echo "`Timestamp` Trying to communicate with XCONF server"
    sendTLSRequest "XCONF"
    curl_result=$TLSRet
    http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
    ret=$?
    echo "`Timestamp` curl_ret = $curl_result, ret=$ret, http_code: $http_code for XCONF communication"
    if [ $curl_result -ne 0 ]; then
        updateFWDownloadStatus "" "Failure" "" "Network Communication Error" "" "" "$runtime" "Failed" "$DelayDownloadXconf"
    elif [ $curl_result -eq 0 ] && [ "$http_code" = "404" ]; then
        exitForXconf404response
    fi    

    return $curl_result
}

sendXCONFCodebigRequest () {
    http_code="000"
    buildType=$(getBuildType)
    request_type=2
    if [ -f $PERSISTENT_PATH/swupdate.conf ] && [ $buildType != "prod" ]; then

        domain_name=`echo $CLOUD_URL | cut -d / -f 3`
        getRequestType $domain_name
        request_type=$?
    fi

    if [ "$request_type" != "0" ]; then
        echo "`Timestamp` Trying to communicate with CodeBig server"
        createJsonString
        if [ "$BUILD_TYPE" != "prod" ]; then
            echo "`Timestamp` JSONSTR: $JSONSTR"
        else
            echo ADDITIONAL_FW_VER_INFO: $pdriFwVerInfo$remoteInfo
        fi
        SIGN_CMD="GetServiceUrl $request_type \"$JSONSTR\""
        eval $SIGN_CMD > /tmp/.signedRequest
        if [ -s /tmp/.signedRequest ]
        then
            echo "GetServiceUrl success"
        else
            echo "GetServiceUrl failed"
            exit 1
        fi
        CB_SIGNED_REQUEST=`cat /tmp/.signedRequest`
        rm -f /tmp/.signedRequest

        sendTLSCodebigRequest "XCONF" 
        curl_result=$TLSRet
        http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
        ret=$?
        echo "`Timestamp` curl_ret = $curl_result, ret=$ret, http_code: $http_code for XCONF communication from Open internet"
        if [ $curl_result -eq 0 ] && [ "$http_code" = "404" ] ; then
            exitForXconf404response
        elif [ $curl_result -ne 0 ]; then
            updateFWDownloadStatus "" "Failure" "" "Network Communication Error" "" "" "$runtime" "Failed" "$DelayDownloadXconf"
        fi
    else
        echo "`Timestamp` sendXCONFCodebigRequest skipped: request_type=$request_type, domain_name=$domain_name"
    fi

    return $curl_result
}

sendXCONFRequest()
{
    http_code="000"
    xconfretry=0
    xconfcbretry=0

    if [ $UseCodebig -eq 1 ]; then
        echo "`Timestamp` sendXCONFRequest Codebig is enabled UseCodebig=$UseCodebig"
        if [ "$DEVICE_TYPE" = "mediaclient" ]; then
            # Use Codebig connection connection on XI platforms
            IsCodeBigBlocked
            skipcodebig=$?
            if [ $skipcodebig -eq 0 ]; then
                while [ $xconfcbretry -le $CB_RETRY_COUNT ]
                do
                    echo "`Timestamp` sendXCONFRequest Using Codebig Image upgrade connection"
                    sendXCONFCodebigRequest
                    ret=$?
                    if [ "$http_code" = "200" ]; then
                       echo "`Timestamp` sendXCONFRequest Codebig Image upgrade  Success: ret=$ret httpcode=$http_code"
                       IsDirectBlocked
                       skipDirect=$?
                       if [ $skipDirect -eq 0 ]; then
                           UseCodebig=0
                       fi
                       break
                    elif [ "$http_code" = "404" ]; then
                        echo "`Timestamp` sendXCONFRequest Received 404 response for Codebig Image upgrade from xconf, Retry logic not needed"
                        break
                    fi
                    echo "`Timestamp` sendXCONFRequest Codebig Image upgrade  return: retry=$xconfcbretry ret=$ret httpcode=$http_code"
                    xconfcbretry=`expr $xconfcbretry + 1`
                    sleep $cbretryDelay
                done	
            fi

            if [ "$http_code" = "000" ] ; then
                echo "`Timestamp` sendXCONFRequest Codebig Image upgrade failed: httpcode=$http_code, Switching direct"
                UseCodebig=0
                sendXCONFTLSRequest 
                ret=$?
                if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                    echo "`Timestamp` sendXCONFRequest Direct image upgrade failover request failed return=$ret, http code=$http_code"
                else
                    echo "`Timestamp` sendXCONFRequest Direct image upgrade failover request received return=$ret, http code=$http_code" 
                fi
                IsCodeBigBlocked
                skipDirect=$?
                if [ $skipDirect -eq 0 ]; then
                    echo "`Timestamp` sendXCONFRequest Codebig blocking is released" 
                fi
            elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then 
                echo "`Timestamp` sendXCONFRequest Codebig Image upgrade failed with httpcode=$http_code"
            fi 
        else
            echo "`Timestamp` sendXCONFRequest Codebig Image upgrade is not supported"
        fi
    else
        echo "`Timestamp` sendXCONFRequest Codebig is disabled UseCodebig=$UseCodebig"
        # Use direct connection connection for 3 failures with appropriate backoff/timeout,.
        IsDirectBlocked
        skipdirect=$?
        if [ $skipdirect -eq 0 ]; then
            while [ $xconfretry -lt $RETRY_COUNT ]
            do 
                echo "`Timestamp` sendXCONFRequest Using Direct Image upgrade connection"
                sendXCONFTLSRequest 
                ret=$?
                if [ "$http_code" = "200" ];then
                    echo "`Timestamp` sendXCONFRequest Direct Image upgrade connection success: ret=$ret httpcode=$http_code"
                    break
                elif [ "$http_code" = "404" ]; then
                    echo "`Timestamp` sendXCONFRequest Received 404 response Direct Image upgrade from xconf, Retry logic not needed"
                    break
                elif [ "$DEVICE_TYPE" = "mediaclient" ] && [ "$http_code" = "000" ]; then
                    echo "`Timestamp` sendXCONFRequest Direct Image upgrade connection return: ret=$ret httpcode=$http_code"
                    if [ "$ret" == "28" ] || [ "$ret" == "6" ]; then
    			echo "`Timestamp` sendXCONFRequest Checking IP and Route configuration"
                        CheckIPRoute
                        foundroute=$?
                        if [ $foundroute -eq 1 ];then
                            echo "`Timestamp` sendXCONFRequest IP and Route configuration found"
    			    echo "`Timestamp` sendXCONFRequest Checking DNS Nameserver configuration"
                            checkDNS_NameServers
                            founddnsservers=$?
                            if [ $founddnsservers -eq 1 ];then
                                echo "`Timestamp` sendXCONFRequest DNS Nameservers are available"
                            else
                                echo "`Timestamp` sendXCONFRequest DNS Nameservers missing..!!"
                            fi
                        else
                            echo "`Timestamp` sendXCONFRequest IP and Route configuration not found...!!"
                        fi
                    fi
                fi
                echo "`Timestamp` sendXCONFRequest Direct Image upgrade  connection return: retry=$xconfretry ret=$ret httpcode=$http_code" 
                xconfretry=`expr $xconfretry + 1`
                sleep $retryDelay
            done
        fi    
    
        if [ "$http_code" = "000" ]; then
            if [ "$DEVICE_TYPE" = "mediaclient" ]; then
                echo "`Timestamp` sendXCONFRequest Direct Image upgrade Failed: httpcode=$http_code attempting codebig" 
                # Use Codebig connection connection on XI platforms
                IsCodeBigBlocked
                skipcodebig=$?
                if [ $skipcodebig -eq 0 ]; then
                    while [ $xconfcbretry -le $CB_RETRY_COUNT ] 
                    do 
                        echo "`Timestamp` sendXCONFRequest Using Codebig Image upgrade connection" 
                        sendXCONFCodebigRequest
                        ret=$?
                        if [ "$http_code" = "200" ]; then
                            echo "`Timestamp` sendXCONFRequest Codebig Image upgrade Success: ret=$ret httpcode=$http_code"
                            UseCodebig=1
                            if [ ! -f $DIRECT_BLOCK_FILENAME ]; then
                                touch $DIRECT_BLOCK_FILENAME
                                echo "`Timestamp` sendXCONFRequest Use CodeBig and Blocking Direct attempts for 24hrs"
                            fi
                            break
                        elif [ "$http_code" = "404" ]; then
                            echo "`Timestamp` sendXCONFRequest Received 404 response Codebig Image upgrade from xconf, Retry logic not needed"
                            break
                        fi
                        echo "`Timestamp` sendXCONFRequest Codebig Image upgrade return: retry=$xconfcbretry ret=$ret httpcode=$http_code" 
                        xconfcbretry=`expr $xconfcbretry + 1`
                        sleep $cbretryDelay
                    done

                    if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                        echo "`Timestamp` sendXCONFRequest Codebig Image upgrade failed: ret=$ret httpcode=$http_code"
                        UseCodebig=0
                        if [ ! -f $CB_BLOCK_FILENAME ]; then
                            touch $CB_BLOCK_FILENAME
                            echo "`Timestamp` sendXCONFRequest Switch Direct and Blocking Codebig for 30mins"
                        fi
                    fi
                fi
            else
                echo "`Timestamp` sendXCONFRequest Codebig Image upgrade is not supported"
            fi
        elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
            echo "`Timestamp` sendXCONFRequest Direct Image upgrade Failed: ret=$ret httpcode=$http_code"
        fi 
    fi
    curl_result=$TLSRet
    return $curl_result
}

sendJsonRequestToCloud()
{
    HTTP_HEADERS='Content-Type: application/json'
    resp=0
    FILENAME=$1
    JSONSTR=""
    createJsonString
    echo "`Timestamp` JSONSTR: $JSONSTR"
    runtime=`date -u +%F' '%T`    

    ## CloudURL to be formed as follows:
    ## get the XRE host name at runtime; XRE_HOST
    ## find the build type - VBN or PROD BUILD
    ## Cloud URL http://$XRE_HOST/firmware/$BUILD/parker/stb/rng210n/version.json
    CLOUD_URL=$(getServURL)
    CLOUD_URL=`echo $CLOUD_URL | sed "s/http:/https:/g"`
    if [ -f $PERSISTENT_PATH/swupdate.conf ] && [ $BUILD_TYPE != "prod" ] ; then
        CURL_OPTION="-gw"
    fi

    updateFWDownloadStatus "" "" "" "" "" "" "$runtime" "Requesting" "$DelayDownloadXconf"
    eventManager $FirmwareStateEvent $FW_STATE_REQUESTING
    sendXCONFRequest 
    ret=$?    

    resp=1
    if [ $ret -ne 0 ] || [ "$http_code" != "200" ] ; then
        echo "`Timestamp` HTTPS request failed"
        
        if [ $curl_result -eq 0 ]; then
            updateFWDownloadStatus "" "Failure" "" "Invalid Request" "" "" "$runtime" "Failed" "$DelayDownloadXconf"
            eventManager $FirmwareStateEvent $FW_STATE_FAILED
        fi
    else
        echo "`Timestamp` HTTPS request success. Processing response.."
        processJsonResponse $FILENAME
        resp=$?
        echo "`Timestamp` processJsonResponse returned $resp"
        if [ $resp -ne 0 ] ; then
            echo "`Timestamp` processing response failed"    
        fi
    fi
    return $resp    
} 

### main app
# Updating the firmware details in status file before network check during boot-up
if [ $triggerType -eq 1 ]; then
    currentFWVersion=$(getFWVersion)
    currentFlashedFileName=""
    if [ -f /tmp/currently_running_image_name ]; then
        currentFlashedFileName=`cat /tmp/currently_running_image_name`
    fi
    # Update the status and failure reason if upgrade failed after flash write
    if [ ! -z $currentFlashedFileName ] && [ ! -z $currentFWVersion ]; then
        echo "$currentFlashedFileName" | grep -q "$currentFWVersion" > /dev/null
        if [ $? -ne 0 ]; then
            if [ -f $STATUS_FILE ]; then
                sed -i "s/Status.*/Status|Failure/" $STATUS_FILE
                sed -i "s/FailureReason.*/FailureReason|Upgrade failed after flash write/" $STATUS_FILE
            fi
            maintenance_error_flag=1
        fi
    fi
    if [ -f $STATUS_FILE ]; then
        sed -i "s/CurrentVersion.*/CurrentVersion|$currentFWVersion/" $STATUS_FILE
        sed -i "s/CurrentFile.*/CurrentFile|$currentFlashedFileName/" $STATUS_FILE
    fi
fi    

if [ -d $DIFW_PATH ]; then
    PWD=`pwd`
    cd $DIFW_PATH
    #Delete already existing files from download folder
    FILE_EXT=$MODEL_NUM*.bin
    rm -f $FILE_EXT
    cd $PWD
fi

# current FW version from version
echo "`Timestamp` version = $(getFWVersion)"
echo "`Timestamp` buildtype = $(getBuildType)"
echo "`Timestamp` partnerId = $(getPartnerId)"

if [ ! -f $WAREHOUSE_ENV ]; then
    getTimeZone
fi

if [ "$(getModel)" != "RPI" ]; then
while [ ! -f /tmp/stt_received ]
do
    echo "Waiting for STT"
    sleep 2
done
echo "`Timestamp` Received STT flag"
fi

UseCodebig=0
echo "`Timestamp` Check Codebig flag..."
IsDirectBlocked
UseCodebig=$?

# Send query to the cloud based on retry count passed in argument
cdlRet=1
retryCount=0
retryDelay=$RETRY_DELAY_XCONF
cbretryDelay=$RETRY_SHORT_DELAY_XCONF

while [ $retryCount -le $RETRY_COUNT_XCONF ]
do
    sendJsonRequestToCloud $FILENAME
    cdlRet=$?
    
    rm -f $FILENAME $HTTP_CODE
    if [ $cdlRet != 0 ]; then
        echo "`Timestamp` sendJsonRequestToCloud failed with httpcode: $http_code Ret: $cdlRet"
        maintenance_error_flag=1
        sleep 5

#update state red status
        if [ $triggerType -eq 6 ]; then
            unsetStateRed
            if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
               then
                 eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
            fi
            exit 1
        else
            stateRedlog "firmware download failed"
            forceStateRed
        fi

        if [ "$http_code" == "404" ];then
            echo "`Timestamp` Giving up all retries as received $http_code response..."
            if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
               then
                 eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
            fi
            exit 1
        fi
    else
        echo "`Timestamp` sendJsonRequestToCloud succeeded with httpcode: $http_code Ret: $cdlRet"
        unsetStateRed
        maintenance_error_flag=0
    fi

    if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ] && [ "x$isCriticalUpdate" != "xtrue" ]
    then  
        abort_flag=`cat /opt/maintenance_mgr_record.conf | cut -d "=" -f2`
        if [ "x$abort_flag" == "xtrue" ]
        then
           eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ABORTED
	   exit 1
        fi
    fi

    retryCount=$((retryCount + 1))
done

#clear file lock before posting event if not cleared previously
rm -f /tmp/DIFD.pid


if [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
    trap - SIGABRT
fi



if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
  then
     if [ "$maintenance_error_flag" -eq 1 ]
        then
            eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
        else
            eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_COMPLETE
        fi
fi


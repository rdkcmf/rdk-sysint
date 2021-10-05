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

if [ "$DEVICE_TYPE" != "mediaclient" ]; then
    if [ -f "$RDK_PATH/commonUtils.sh" ]; then
        . $RDK_PATH/commonUtils.sh
    fi
else
    if [ -f "$RDK_PATH/utils.sh" ]; then
        . $RDK_PATH/utils.sh
    fi
fi

# override evn if RFC desires
if [ -f $RDK_PATH/rfcOverrides.sh ]; then
    . $RDK_PATH/rfcOverrides.sh
fi

LOG_FILE=$LOG_PATH/"swupdate.log"
THIS_SCRIPT=`basename "$0"`

IARM_EVENT_BINARY_LOCATION=/usr/bin
if [ ! -f /etc/os-release ]; then
    IARM_EVENT_BINARY_LOCATION=/usr/local/bin
fi

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

#Upgrade events
FirmwareStateEvent="FirmwareStateEvent"
ImageDwldEvent="ImageDwldEvent"

## Flag to indicate RCDL is in progress
RCDL_FLAG="/tmp/device_initiated_rcdl_in_progress"

# File to save http code
HTTP_CODE="/tmp/rcdl_curl_httpcode"

DnldURLvalue="/opt/.dnldURL"

RETRY_COUNT=3
CB_RETRY_COUNT=1
DIRECT_BLOCK_FILENAME="/tmp/.lastdirectfail_userdl"
CB_BLOCK_FILENAME="/tmp/.lastcodebigfail_userdl"

IMAGE_FILE_NAME="/tmp/rcdlImageName.txt"
IMAGE_PATH="/tmp/rcdlImageLocation.txt"

DEFER_REBOOT_STATUS_FILE="/tmp/rcdldeferReboot.txt"
DEFER_REBOOT=0

cloudProto="http"
REBOOT_PENDING_DELAY=3
isMmgbleNotifyEnabled=$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.ManageableNotification.Enable 2>&1 > /dev/null)
DAC15_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Sysint.DAC15CDLUrl 2>&1)
WEBPACDL_TR181_NAME="Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.NonPersistent.WebPACDL.Enable"
if [ -z "$DAC15_URL" ]; then
    DAC15_URL="dac15cdlserver.ae.ccp.xcal.tv"
fi

#setting TLS value only for Yocto builds
TLS=""
if [ -f /etc/os-release ]; then
    TLS="--tlsv1.2"
fi

CURL_TLS_TIMEOUT=30

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

#Support for firmware download via codebig
REQUEST_TYPE_FOR_CODEBIG_URL=14

FOUR_CMDLINE_PARAMS=4

log ()
{
    echo "`Timestamp` $THIS_SCRIPT: $*" >> "$LOG_FILE"
}

#Cert ops STB Red State recovery RDK-30717
stateRedFlag="/tmp/stateRedEnabled"
stateRedSprtFile="/lib/rdk/stateRedRecovery.sh"

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
        log "checkAndEnterStateRed: Device State Red Recovery Flag already set"
        stateRedRecoveryUrl=$recoveryURL
        return
    fi

#Enter state red on ssl or cert errors
    case $curlReturnValue in
    35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
        rm -f $DIRECT_BLOCK_FILENAME
        rm -f $CB_BLOCK_FILENAME
        touch $stateRedFlag
        log "checkAndEnterStateRed: Curl SSL/TLS error ($curlReturnValue). Set state Red and Exit" >> $LOG_PATH/tlsError.log
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
        remtime=$(($modtime/3600))
        if [ "$modtime" -le "$DIRECT_BLOCK_TIME" ]; then
            log "userInitiatedFWDnld: Last direct failed blocking is still valid for $remtime hrs, preventing direct"
            directret=1
        else
            log "userInitiatedFWDnld: Last direct failed blocking has expired, removing $DIRECT_BLOCK_FILENAME, allowing direct"
            rm -f $DIRECT_BLOCK_FILENAME
        fi
    fi
    return $directret
}

IsCodeBigBlocked()
{
    codebigret=0
    if [ -f $CB_BLOCK_FILENAME ]; then
        modtime=$(($(date +%s) - $(date +%s -r $CB_BLOCK_FILENAME)))
        cbremtime=$(($modtime/60))
        if [ "$modtime" -le "$CB_BLOCK_TIME" ]; then
            log "userInitiatedFWDnld: Last Codebig failed blocking is still valid for $cbremtime mins, preventing Codebig"
            codebigret=1
        else
            log "userInitiatedFWDnld: Last Codebig failed blocking has expired, removing $CB_BLOCK_FILENAME, allowing Codebig"
            rm -f $CB_BLOCK_FILENAME
        fi
    fi
    return $codebigret
}

getCodebigUrl()
{
    request_type=$REQUEST_TYPE_FOR_CODEBIG_URL
    json_str='/Images''/$UpgradeFile'
    if [ "$domainName" == "$DAC15_URL" ]; then
        request_type=14
    fi
    sign_cmd="GetServiceUrl $request_type \"$json_str\""
    eval $sign_cmd > /tmp/.signedRequest
    if [ -s /tmp/.signedRequest ]
    then
        echo "GetServiceUrl success"
    else
        echo "GetServiceUrl failed"
        exit 1
    fi
    cb_signed_request=`cat /tmp/.signedRequest`
    rm -f /tmp/.signedRequest
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

## Function to update firmware download status
updateFWDnldStatus()
{
    FW_DNLD_STATUS_FILE="/opt/fwdnldstatus.txt"

    proto=$1
    status=$2
    failureReason=$3
    DnldVersn=$4
    DnldFile=$5
    LastRun=$6
    Codebig=$7
    DnldPercent=""
    LastSuccessfulRun=`grep LastSuccessfulRun $FW_DNLD_STATUS_FILE | cut -d '|' -f2`
    CurrentVersion=`grep imagename /version.txt | cut -d':' -f2`
    CurrentFile=`cat /tmp/currently_running_image_name`
    LastSuccessfulUpgradeFile=`cat /opt/cdl_flashed_file_name`
    reboot="true"
    fwUpdateState=$8
    if [ "$DEFER_REBOOT" = "1" ];then
        reboot="false"
    fi

    if [ -f $FW_DNLD_STATUS_FILE ]
    then
        rm $FW_DNLD_STATUS_FILE
    fi
    touch $FW_DNLD_STATUS_FILE

    echo "Proto|$proto" >> $FW_DNLD_STATUS_FILE
    echo "Status|$status" >> $FW_DNLD_STATUS_FILE
    echo "Reboot|$reboot" >> $FW_DNLD_STATUS_FILE
    echo "FailureReason|$failureReason" >> $FW_DNLD_STATUS_FILE
    echo "DnldVersn|$DnldVersn" >> $FW_DNLD_STATUS_FILE
    echo "DnldFile|$DnldFile" >> $FW_DNLD_STATUS_FILE
    echo "DnldURL|`cat $DnldURLvalue`" >> $FW_DNLD_STATUS_FILE
    echo "DnldPercent|$DnldPercent" >> $FW_DNLD_STATUS_FILE
    echo "LastRun|$LastRun" >> $FW_DNLD_STATUS_FILE
    echo "Codebig_Enable|$Codebig" >> $FW_DNLD_STATUS_FILE
    echo "LastSuccessfulRun|$LastSuccessfulRun" >> $FW_DNLD_STATUS_FILE
    echo "CurrentVersion|$CurrentVersion" >> $FW_DNLD_STATUS_FILE
    echo "CurrentFile|$CurrentFile" >> $FW_DNLD_STATUS_FILE
    echo "LastSuccessfulUpgradeFile|$LastSuccessfulUpgradeFile" >> $FW_DNLD_STATUS_FILE
    echo "FwUpdateState|$fwUpdateState" >> $FW_DNLD_STATUS_FILE
}

sendTLSRequest()
{
    TLSRet=1

    CodebigFlag=$1
    EnableOCSPstaple="/tmp/.EnableOCSPStapling"
    EnableOCSP="/tmp/.EnableOCSPCA"

    # Set reboot flag to true
    REBOOT_FLAG=1
    if [ "$DEFER_REBOOT" = "1" ];then
        REBOOT_FLAG=0
    fi

    if [ $CodebigFlag -eq 1 ]; then
       log "sendTLSRequest: Using $TLS codebig connection"
       if [ -f $EnableOCSPstaple ] || [ -f $EnableOCSP ]; then
          CURL_CMD="curl $TLS --cert-status --connect-timeout $CURL_TLS_TIMEOUT -w '%{http_code}\n' -o \"$DIFW_PATH/$UPGRADE_FILE\" \"$imageHTTPURL\""
          if [ "$DEVICE_TYPE" == "mediaclient" ]; then
             if [ "$isThrottleEnabled" = "true" ] && [ ! -z "$VIDEO" ] && [ "$REBOOT_FLAG" != "1" ]; then
                echo "Throttle is enabled and Video is Streaming"
                CURL_CMD="$CURL_CMD --speed-limit $LOWSPEED --limit-rate $TOPSPEED"
             else
                if [ "$isThrottleEnabled" = "true" ] && [ "$REBOOT_FLAG" = "1" ]; then
                   echo "Throttle is enabled but cloudImmediateRebootFlag is true"
                   echo "Continuing with the Unthrottle mode"
                else
                   echo "Throttle is disabled"
                fi
                CURL_CMD="$CURL_CMD --speed-limit $LOWSPEED"
             fi
          fi
          log "Codebig enabled ==> CURL_CMD: $CURL_CMD"
       else
          CURL_CMD="curl $TLS --connect-timeout $CURL_TLS_TIMEOUT -w '%{http_code}\n' -o \"$DIFW_PATH/$UPGRADE_FILE\" \"$imageHTTPURL\""
          if [ "$DEVICE_TYPE" == "mediaclient" ]; then
             if [ "$isThrottleEnabled" = "true" ] && [ ! -z "$VIDEO" ] && [ "$REBOOT_FLAG" != "1" ]; then
                echo "Throttle is enabled and Video is Streaming"
                CURL_CMD="$CURL_CMD --speed-limit $LOWSPEED --limit-rate $TOPSPEED"
             else
                if [ "$isThrottleEnabled" = "true" ] && [ ! -z "$VIDEO" ] && [ "$REBOOT_FLAG" = "1" ]; then
                   echo "Throttle is enabled and Video is Streaming but cloudImmediateRebootFlag is true"
                   echo "Continuing with the Unthrottle mode"
                else
                   echo "Throttle is disabled"
                fi
                CURL_CMD="$CURL_CMD --speed-limit $LOWSPEED"
             fi
          fi
          log "Codebig enabled ==> CURL_CMD: $CURL_CMD"
       fi
    else
       log "sendTLSRequest: Using $TLS direct connection"
       if [ -f $EnableOCSPstaple ] || [ -f $EnableOCSP ]; then
          CURL_CMD="curl $TLS --cert-status --connect-timeout $CURL_TLS_TIMEOUT -w '%{http_code}\n' -fgLO \"$imageHTTPURL\""
          if [ "$DEVICE_TYPE" == "mediaclient" ]; then
             if [ "$isThrottleEnabled" = "true" ] && [ ! -z "$VIDEO" ] && [ "$REBOOT_FLAG" != "1" ]; then
                echo "Throttle is enabled and Video is Streaming"
                CURL_CMD="$CURL_CMD --speed-limit $LOWSPEED --limit-rate $TOPSPEED"
             else
                if [ "$isThrottleEnabled" = "true" ] && [ ! -z "$VIDEO" ] && [ "$REBOOT_FLAG" = "1" ]; then
                   echo "Throttle is enabled and Video is Streaming but cloudImmediateRebootFlag is true"
                   echo "Continuing with the Unthrottle mode"
                else
                   echo "Throttle is disabled"
                fi
                CURL_CMD="$CURL_CMD --speed-limit $LOWSPEED"
             fi
          fi
          log "Codebig not enabled ==> CURL_CMD: $CURL_CMD"
       else
          CURL_CMD="curl $TLS --connect-timeout $CURL_TLS_TIMEOUT -w '%{http_code}\n' -fgLO \"$imageHTTPURL\""
          if [ "$DEVICE_TYPE" == "mediaclient" ]; then
             if [ "$isThrottleEnabled" = "true" ] && [ ! -z "$VIDEO" ] && [ "$REBOOT_FLAG" != "1" ]; then
                echo "Throttle is enabled and Video is Streaming"
                CURL_CMD="$CURL_CMD --speed-limit $LOWSPEED --limit-rate $TOPSPEED"
             else
                if [ "$isThrottleEnabled" = "true" ] && [ ! -z "$VIDEO" ] && [ "$REBOOT_FLAG" = "1" ]; then
                   echo "Throttle is enabled and Video is Streaming but cloudImmediateRebootFlag is true"
                   echo "Continuing with the Unthrottle mode"
                else
                   echo "Throttle is disabled"
                fi
                CURL_CMD="$CURL_CMD --speed-limit $LOWSPEED"
             fi
          fi
          log "Codebig not enabled ==> CURL_CMD: $CURL_CMD"
       fi
    fi
    eval $CURL_CMD > $HTTP_CODE

    TLSRet=$?
    if [ $TLSRet -eq 28 ]; then
       # Curl returns 28 if speed is less than 100 kbit/sec
       # curl: (28) Operation too slow. Less than 12800 bytes/sec transferred the last 30 seconds
       echo "CDL is suspended because speed is below 100 kbit/second"
    fi

    case $TLSRet in
        35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
            log "HTTPS $TLS failed to connect to server with curl error code $TLSRet" >> $LOG_PATH/tlsError.log
        ;;

    esac

#if there is a failure due to tls error enter state red
    checkAndEnterStateRed $TLSRet

    return $TLSRet
}

## trigger image download to the box
imageDownloadToLocalServer ()
{
    log "imageDownloadToLocalServer: Triggering the Image CDL ..."

    UPGRADE_LOCATION=$1
    log "UPGRADE_LOCATION = $UPGRADE_LOCATION"

    #Enforce https
    UPGRADE_LOCATION=`echo $UPGRADE_LOCATION | sed "s/http:/https:/g"`

    UPGRADE_FILE=$2
    log "UPGRADE_FILE = $UPGRADE_FILE"

    CodebigFlag=$3
    log "DIFW_PATH = $DIFW_PATH"

    if [ ! -d $DIFW_PATH ]; then
         mkdir -p $DIFW_PATH
    fi

    cd $DIFW_PATH
    if [ $CodebigFlag -eq 1 ]; then
        imageHTTPURL="$UPGRADE_LOCATION"
    else
        # Change to support whether full http URL
        imageHTTPURL="$UPGRADE_LOCATION/$UPGRADE_FILE"
    fi
    log "imageHTTPURL = $imageHTTPURL"
    echo "$imageHTTPURL" > $DnldURLvalue

    ret=1
    model_num=$MODEL_NUM
    FILE_EXT=$model_num*.bin
    rm -f $FILE_EXT

    updateFWDnldStatus "$cloudProto" "ESTB in progress" "" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "Downloading"
    log "imageDownloadToLocalServer: Started image download ..."

    #Set FirmwareDownloadStartedNotification before starting of firmware download
    if [ "${isMmgbleNotifyEnabled}" == "true" ]; then
        current_time=`date +%s`
        echo "current_time calculated as $current_time"
        tr181 -s -v $current_time  Device.DeviceInfo.X_RDKCENTRAL-COM_xOpsDeviceMgmt.RPC.FirmwareDownloadStartedNotification
        echo "FirmwareDownloadStartedNotification SET succeeded"
    fi
    if [ "$Protocol" = "usb" ]; then
	DEFER_REBOOT=1
	# Overwrite the path to program directly from the USB
        DIFW_PATH=$UPGRADE_LOCATION
        if [ ! -f $DIFW_PATH/$UPGRADE_FILE ]; then
	    log "Error: $DIFW_PATH/$UPGRADE_FILE not found"
            http_code="404"
        else
            ret=0
            http_code="200"
        fi
    else
        sendTLSRequest $CodebigFlag
        ret=$?
        http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
    fi

    if [ $ret -ne 0 ] || [ "$http_code" != "200" ]; then
        log "Local image Download Failed ret:$ret, httpcode:$http_code, Retrying"
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
        updateFWDnldStatus "$cloudProto" "Failure"  "$failureReason" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "Failed"
        eventManager $FirmwareStateEvent $FW_STATE_FAILED

        if [ "${isMmgbleNotifyEnabled}" == "true" ]; then
            #Set FirmwareDownloadCompletedNotification after firmware download
            tr181 -s -v false  Device.DeviceInfo.X_RDKCENTRAL-COM_xOpsDeviceMgmt.RPC.FirmwareDownloadCompletedNotification
            echo "FirmwareDownloadCompletedNotification SET to false succeeded"
        fi
        return $ret
    else
        log "Local image Download Success ret:$ret"

        if [ "${isMmgbleNotifyEnabled}" == "true" ]; then
            #Set FirmwareDownloadCompletedNotification after firmware download
            tr181 -s -v true  Device.DeviceInfo.X_RDKCENTRAL-COM_xOpsDeviceMgmt.RPC.FirmwareDownloadCompletedNotification
            echo "FirmwareDownloadCompletedNotification SET to true succeeded"
        fi
    fi
    log "$UPGRADE_FILE Local Image Download Completed with status=$ret!"

    # Set reboot flag to true
    REBOOT_FLAG=1
    if [ "$DEFER_REBOOT" = "1" ];then
        REBOOT_FLAG=0
    fi

    if [ "$DEVICE_TYPE" = "mediaclient" ]
    then
        # invoke device/soc specific flash app
        /lib/rdk/imageFlasher.sh $cloudProto $UPGRADE_LOCATION $DIFW_PATH $UPGRADE_FILE
        ret=$?
        if [ "$ret" -ne 0 ]; then
            updateFWDnldStatus "$cloudProto" "Failure" "Flashing failed" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "Failed"
             eventManager $FirmwareStateEvent $FW_STATE_FAILED
        else
            updateFWDnldStatus "$cloudProto" "Success" "" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "Validation complete"
	    eventManager $FirmwareStateEvent $FW_STATE_VALIDATION_COMPLETE
            echo "$UPGRADE_FILE" > /opt/cdl_flashed_file_name
            if [ "$REBOOT_FLAG" = "1" ] && [ "$Protocol" != "usb" ]; then
		eventManager $FirmwareStateEvent $FW_STATE_PREPARING_TO_REBOOT
                rm -rf /opt/.gstreamer
                if [ "${isMmgbleNotifyEnabled}" == "true" ]; then
                    echo "Trigger RebootPendingNotification in background"
                    Trigger_RebootPendingNotify &
                fi
                echo "sleep for $REBOOT_PENDING_DELAY sec to send reboot pending notification"
                (sleep $REBOOT_PENDING_DELAY; /rebootNow.sh -s ImageUpgrade_"`basename $0`" -o "Rebooting the box after RCDL Image Upgrade...") & # reboot explicitly. imageFlasher.sh only flashes, will not reboot device.
            fi
        fi
        # image file can be deleted now
        if [ "$Protocol" != "usb" ]; then
            rm -rf $DIFW_PATH/$UPGRADE_FILE
        fi
    else
        imagePath="\"$DIFW_PATH/"$UPGRADE_FILE"\""
        log "imagePath = $imagePath"
        if [ "$CPU_ARCH" == "x86" ]; then
             updateFWDnldStatus "$cloudProto" "Triggered ECM download" "" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" ""
        fi
        if [ "$DEVICE_TYPE" = "hybrid" ]
        then
            # invoke rmfAPICaller here
            /usr/bin/rmfapicaller vlMpeosCdlUpgradeToImage 0 2 $REBOOT_FLAG $imagePath
        else
            # invoke vlAPICaller here
            /mnt/nfs/bin/vlapicaller vlMpeosCdlUpgradeToImage 0 2 $REBOOT_FLAG $imagePath
        fi
        ret=$?
        if [ $ret -ne 0 ]; then
            if [ "$CPU_ARCH" != "x86" ]; then
               updateFWDnldStatus "$cloudProto" "Failure" "RCDL Upgrade Failed" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "Failed"
            else
               updateFWDnldStatus "$cloudProto" "Failure" "ECM trigger failed" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "Failed"
            fi
        else
            updateFWDnldStatus "$cloudProto" "Success" "" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "Validation complete"
            eventManager $FirmwareStateEvent $FW_STATE_VALIDATION_COMPLETE
            echo "$UPGRADE_FILE" > /opt/cdl_flashed_file_name
        fi
    fi
    return $ret
}

ProcessImageUpgradeRequest()
{
    ret=1
    UpgradeLocation=$1
    UpgradeFile=$2
    CodebigFlag=$3
    http_code="000"
    retries=0
    cbretries=0

    if [ -f /tmp/currently_running_image_name ]
    then
        myFWFile=`cat /tmp/currently_running_image_name`
        currentFile=$myFWFile
        myFWFile=`echo $myFWFile | tr '[A-Z]' '[a-z]'`
    fi
    log "myFWFile = $myFWFile"

    if [ -f /opt/cdl_flashed_file_name ]
    then
        lastDnldFile=`cat /opt/cdl_flashed_file_name`
        lastDnldFileName=$lastDnldFile
        lastDnldFile=`echo $lastDnldFile | tr '[A-Z]' '[a-z]'`
    fi
    log "lastDnldFile = $lastDnldFile "

    if [ "$Protocol" = "usb" ]; then
        imageDownloadToLocalServer $UpgradeLocation $UpgradeFile 0
        resp=$?
    elif [ "$myFWFile" = "$dnldFile" ]; then
        log "FW version of the active image and the image to be upgraded are the same. No upgrade required."
        updateFWDnldStatus "$cloudProto" "No upgrade needed" "Versions Match" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "No upgrade needed"
    elif [ "$lastDnldFile" = "$dnldFile" ]; then
        log "FW version of the standby image and the image to be upgraded are the same. No upgrade required."
        updateFWDnldStatus "$cloudProto" "No upgrade needed" "Versions Match" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "No upgrade needed"
    else
        if [ $CodebigFlag -eq 1 ]; then
            log "ProcessImageUpgradeRequest: Codebig is enabled UseCodebig=$CodebigFlag"
                # Use Codebig connection connection on XI platforms
                # When codebig is set, use the DAC15 signed codebig URL for firmware download
                IsCodeBigBlocked
                skipcodebig=$?
                if [ $skipcodebig -eq 0 ]; then
                    while [ "$cbretries" -le $CB_RETRY_COUNT ]
                    do
                        log "ProcessImageUpgradeRequest: Attempting Codebig firmware download"
                        getCodebigUrl
                        imageDownloadToLocalServer $cb_signed_request $UpgradeFile $CodebigFlag
                        resp=$?
                        http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                        if [ "$http_code" = "200" ]; then
                            log "ProcessImageUpgradeRequest: Codebig firmware download Success - ret:$resp, httpcode:$http_code"
                            IsDirectBlocked
                            skipDirect=$?
                            if [ $skipDirect -eq 0 ]; then
                                CodebigFlag=0
                            fi
                            break
                        elif [ "$http_code" = "404" ]; then
                            log "ProcessImageUpgradeRequest: Received 404 response for Codebig firmware download, Retry logic not needed"
                            break
                        fi
                        log "ProcessImageUpgradeRequest: Codebig firmware download return - retry:$cbretries, ret:$resp, httpcode:$http_code"
                        cbretries=`expr $cbretries + 1`
                        sleep 10
                    done
                fi

                if [ "$http_code" = "000" ]; then
                    IsDirectBlocked
                    skipdirect=$?
                    if [ $skipdirect -eq 0 ]; then
                        log "ProcessImageUpgradeRequest: Codebig firmware download failed - httpcode:$http_code, Using Direct"
                        CodebigFlag=0
                        imageDownloadToLocalServer $UpgradeLocation $UpgradeFile $CodebigFlag
                        resp=$?
                        http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                        if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                            log "ProcessImageUpgradeRequest: Direct failover firmware download failed - ret:$resp, httpcode:$http_code"
                        else
                            log "ProcessImageUpgradeRequest: Direct failover firmware download received- ret:$resp, httpcode:$http_code"
                        fi
                    fi
                    IsCodeBigBlocked
                    skipCodeBig=$?
                    if [ $skipCodeBig -eq 0 ]; then
                        log "ProcessImageUpgradeRequest: Codebig block released"
                    fi
                elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                    log "ProcessImageUpgradeRequest: Codebig firmware download failed with httpcode:$http_code"
                fi
        else
            log "ProcessImageUpgradeRequest: Codebig is disabled UseCodebig=$CodebigFlag"
            IsDirectBlocked
            skipdirect=$?
            if [ $skipdirect -eq 0 ]; then
                while [ "$retries" -lt $RETRY_COUNT ]
                do
                    log "ProcessImageUpgradeRequest: Attempting Direct firmware download"
                    CodebigFlag=0
                    imageDownloadToLocalServer $UpgradeLocation $UpgradeFile $CodebigFlag
                    resp=$?
                    http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                    if [ "$http_code" = "200" ];then
                       log "ProcessImageUpgradeRequest: Direct firmware download success - ret:$resp, httpcode:$http_code"
                       break
                    elif [ "$http_code" = "404" ]; then
                       log "ProcessImageUpgradeRequest: Received 404 response for Direct firmware download, Retry logic not needed"
                       break
                    fi
                    log "ProcessImageUpgradeRequest: Direct firmware download return - retry:$retries, ret:$resp, httpcode:$http_code"
                    retries=`expr $retries + 1`
                    sleep 60
                done
            fi

            if [ "$http_code" = "000" ]; then
                if [ "$DEVICE_TYPE" == "mediaclient" ]; then
                    log "ProcessImageUpgradeRequest: Direct firmware download failed - httpcode:$http_code, attempting Codebig"
                    IsCodeBigBlocked
                    skipcodebig=$?
                    if [ $skipcodebig -eq 0 ]; then
                        while [ $cbretries -le $CB_RETRY_COUNT ]
                        do
                            log "ProcessImageUpgradeRequest: Attempting Codebig firmware download"
                            CodebigFlag=1
                            getCodebigUrl
                            imageDownloadToLocalServer $cb_signed_request $UpgradeFile $CodebigFlag
                            resp=$?
                            http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                            if [ "$http_code" = "200" ]; then
                                log "ProcessImageUpgradeRequest: Codebig firmware download success - ret:$resp, httpcode:$http_code"
                                CodebigFlag=1
                                if [ ! -f $DIRECT_BLOCK_FILENAME ]; then
                                    touch $DIRECT_BLOCK_FILENAME
                                    log "ProcessImageUpgradeRequest: Use Codebig and Block Direct for 24 hrs "
                                fi
                                break
                            elif [ "$http_code" = "404" ]; then
                                log "ProcessImageUpgradeRequest: Received 404 response for Codebig firmware download, Retry logic not needed"
                                break
                            fi
                            log "ProcessImageUpgradeRequest: Codebig firmware download return - retry:$cbretries, ret:$resp, httpcode:$http_code"
                            cbretries=`expr $cbretries + 1`
                            sleep 10
                        done

                        if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                            log "ProcessImageUpgradeRequest: Codebig firmware download failed - ret:$resp, httpcode:$http_code"
                            CodebigFlag=0
                            if [ ! -f $CB_BLOCK_FILENAME ]; then
                                touch $CB_BLOCK_FILENAME
                                log "ProcessImageUpgradeRequest: Switch Direct and Blocking Codebig for 30mins"
                            fi
                        fi
                    fi
                else
                    log "ProcessImageUpgradeRequest: Codebig firmware download is not supported"
                fi
            elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                log "ProcessImageUpgradeRequest: Direct firmware download failed - ret:$resp, httpcode:$http_code"
            fi
        fi

        log "ProcessImageUpgradeRequest: firmware upgrade codebig:$CodebigFlag method returned $resp httpcode:$http_code"

        if [ $resp = 0 ] && [ "$http_code" = "404" ]; then
            log "ProcessImageUpgradeRequest: doCDL failed with HTTPS 404 Response from Xconf Server"
            log "Exiting from Image Upgrade process..!"
            exit 0
        elif [ $resp != 0 ] || [ "$http_code" != "200" ]; then
            log "ProcessImageUpgradeRequest: doCDL failed"
        else
            log "ProcessImageUpgradeRequest: doCDL success"
            if [ "$DEFER_REBOOT" = "1" ];then
                log "ProcessImageUpgradeRequest: Deferring reboot after firmware download."
            else
                log "ProcessImageUpgradeRequest: Rebooting after firmware download."
            fi
            ret=0
        fi
    fi
    rm -f $RCDL_FLAG #Removing lock only after all the retries are failed
    return $ret
}

IsWebpacdlEnabledForProd()
{
    if [ "$Protocol" = "usb" ]; then
        log "USB S/W upgrade, skipping check for webPA CDL RFC value"
    else
        #For PROD images, RFC(Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.NonPersistent.WebPACDL.Enable) should be TRUE
        log "Check for webPA CDL RFC value"
        if [ -f /usr/bin/tr181 ]; then
            WebPACDL=`/usr/bin/tr181 -g $WEBPACDL_TR181_NAME 2>&1 > /dev/null`
        else
            log "tr181 BIN is not available at this time, setting WebPACDL to Default value(False)."
            WebPACDL=false
        fi
        log "WebPACDL=$WebPACDL"
        Build_type=`echo $ImageName | grep -i "_PROD_" | wc -l`
        if [ "$Build_type" -ne 0 ] && [ "$WebPACDL" != "true" ]; then
            log "Exiting!!! Either Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.NonPersistent.WebPACDL.Enable is FALSE or RFC sync not completed yet."
            exit 1
        fi
    fi
}

### main app
estbIp=`getIPAddress`

# Checking number of cmd line params passed to script file

if [ $# -lt $FOUR_CMDLINE_PARAMS ]; then
     log "Error: minimum $FOUR_CMDLINE_PARAMS params needed, so Exiting !!!"
     log "USAGE: <Path to userInitiatedFWDnld.sh file> <protocol> <ImageServer_URL> <Image_Name> <Codebig_Flag> <Defer_Reboot>(To enable set 1, To disable set 0)"
     log "Example (For Non-Cogent network): /lib/rdk/userInitiatedFWDnld.sh http <ImageServer_URL> <Image_Name> 0 0"
     log "Example (For Cogent network): /lib/rdk/userInitiatedFWDnld.sh http <ImageServer_URL> <Image_Name> 1 1"
exit 1
fi

cleanup()
{
    log "cleanup..."
    if [ -f $HTTP_CODE ]; then
        log "http code file removed"
        rm -f $HTTP_CODE
    fi
    if [ -f $RCDL_FLAG ]; then
        log "Lock removed"
        rm -f $RCDL_FLAG
    fi
}

if [ "$estbIp" = "$DEFAULT_IP" ]; then
    log "waiting for IP ..."
    sleep 15
else
    log "--------- $interface got an ip $estbIp"

    ## Initialize the DIFD status/log file
    runtime=`date -u +%F' '%T`

    log " Using script arguments $2 and $3 to download..."

    CodebigFlag=$4
    ImageName=$3
    ImagePath=$2
    Protocol=$1
    DEFER_REBOOT=$5

    if [ "$DEFER_REBOOT" != "1" ]; then
        DEFER_REBOOT=0;
    fi

    log "ImageName = $ImageName"
    log "ImagePath = $ImagePath"
    log "DEFER_REBOOT = $DEFER_REBOOT"

    if [ -f $RCDL_FLAG ]; then
	log "Image download already in progress, exiting!"
	exit 1
    elif [ ! -z "$ImageName" ] && [ ! -z "$ImagePath" ]; then
        IsWebpacdlEnabledForProd
        log "Found download details, triggering download..."
        touch $RCDL_FLAG
        trap cleanup EXIT #Remove Lock upon exit
        dnldVersion=`echo $ImageName | sed  's/-signed.bin//g' | sed  's/.bin//g'`
        dnldFile=`echo $ImageName | tr '[A-Z]' '[a-z]'`
	eventManager $FirmwareStateEvent $FW_STATE_REQUESTING
        ProcessImageUpgradeRequest $ImagePath $ImageName $CodebigFlag
        exit $?
    else
        log "rcdlUpgradeFile or rcdlUpgradeFilePath is empty. Exiting !!!"
        exit 1
    fi
fi

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
. $RDK_PATH/utils.sh

if [ -f $RDK_PATH/rfcOverrides.sh ]; then
    . $RDK_PATH/rfcOverrides.sh
fi

IPDL_LOG_FILE="$LOG_PATH/ipdllogfile.txt"
httpServerConf="/opt/httpServer.conf"
## File containing common firmware download state variables
STATUS_FILE="/opt/fwdnldstatus.txt"
## Text for state variable 'Status' indicating firmware upgrade in progress
UPGRADE_IN_PROGRESS_STRING1="Download In Progress"
UPGRADE_IN_PROGRESS_STRING2="Flashing In Progress"
## Downlad in progress flag
dnldInProgressFlag="/tmp/.imageDnldInProgress"
dnldFileName=""
## File storing CDL Flashed filename including signed extension
FLASH_FILE_NAME="/opt/cdl_flashed_file_name"
SVR_MAC_ADDRESS_LOCATION="macAddressConf"
RETRY_COUNT=3
httpURL=""
ImageDownloadURL=""
DnldURLvalue="/opt/.dnldURL"
TLS="--tlsv1.2"
# File to save http code
HTTP_CODE="/tmp/rcdl_curl_httpcode"

export LD_LIBRARY_PATH=/lib:/usr/local/lib:
rm -rf $HTTP_CODE

PRODCDL_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Sysint.PRODCDLUrl  2>&1)
if [ -z "$PRODCDL_URL" ]; then
    PRODCDL_URL="https://prodcdlserver.ae.ccp.xcal.tv/Images"
fi

swupdateLog()
{
    echo "`/bin/timestamp`: $0: $*" >> $IPDL_LOG_FILE
}

getMocaMacAddress()
{
    ifconfig  | grep -w $MOCA_INTERFACE |  grep -w -v $MOCA_INTERFACE:0 | tr -s ' ' | cut -d ' ' -f5
}

## FW version from version 
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

## Previous downloaded firmware version from /opt/fwdnldstatus.txt
getPreviousDnldFWVersion()
{
    prevDnldFWVersion=""
    if [ -f $STATUS_FILE ]; then
        prevDnldFWVersion=`cat $STATUS_FILE | grep "DnldVersn" | cut -d '|' -f2`
    fi
    echo "$prevDnldFWVersion"
}

## Function to update Firmware download status in log file /opt/fwdnldstatus.txt
## Args : 1] Upgrade status 2] Failure Reason
## Args : 3] Download File Version 4] Download File Name
## Args : 5] The latest date and time at which download had started
## Args : 6] Current image version 7] Current File Name
updateFWDownloadStatusLog()
{
    status=$1
    failureReason=$2
    DnldVersn=$3
    DnldFile=$4
    LastRun=$5
    CurrVersn=$6
    CurrFile=$7
    numberOfArgs=$#
    # Check to avoid error in status due error in argument count during logging
    if [ "$numberOfArgs" -ne "7" ]; then
        swupdateLog "Error in number of args for logging status in fwdnldstatus.txt"
    fi

    echo "Method|http" > $STATUS_FILE
    echo "Proto|http" >> $STATUS_FILE
    echo "Status|$status" >> $STATUS_FILE
    echo "Reboot|Immediate" >> $STATUS_FILE
    echo "FailureReason|$failureReason" >> $STATUS_FILE
    echo "CurrVersn|$CurrVersn" >> $STATUS_FILE
    echo "CurrFile|$CurrFile" >> $STATUS_FILE
    echo "DnldVersn|$DnldVersn" >> $STATUS_FILE
    echo "DnldFile|$DnldFile" >> $STATUS_FILE
    echo "DnldURL|`cat $DnldURLvalue`" >> $STATUS_FILE
    echo "LastRun|$LastRun" >> $STATUS_FILE

}

# identifies whether it is a VBN or PROD build
getBuildType()
{
    if [ ! -n "$BUILD_TYPE" ] || [ "$BUILD_TYPE" == "" ] ; then
        echo 'dev'
    else
        echo "$BUILD_TYPE"
    fi
}

getHTTPaddr()
{
    httpURL="$PRODCDL_URL"
    if [ "$BUILD_TYPE" != "prod" ] && [ -f $httpServerConf ]; then
        httpURL=`grep -v '^[[:space:]]*#' $httpServerConf`
        echo "$httpURL" | grep -q -i "^http.*://"
        if [ $? -ne 0 ]; then
            swupdateLog "Device configured with an invalid overriden URL : $httpURL !!! Using default URL"
            httpURL="$PRODCDL_URL"
        fi
    fi

    httpURL=`echo $httpURL | sed "s/http:/https:/g"`
    swupdateLog "URL:$httpURL"
}

downloadImage()
{
     UPGRADE_FILE=$1

     getHTTPaddr
     imageHTTPURL="$httpURL/$UPGRADE_FILE"
     ImageDownloadURL=$imageHTTPURL
     echo "$imageHTTPURL" > $DnldURLvalue
     swupdateLog "PROTO: HTTP , IMAGE URL= $imageHTTPURL"
     ret=1
     retryCount=0
     while [ $ret -ne 0 ]
     do
         retryCount=$((retryCount + 1))
         # Clean up of existing files before image download retries
         if [ -d $DIFW_PATH ] ; then
             model_num=$(getModel)
             FILE_EXT=$model_num*.bin*
             rm -f $DIFW_PATH/$FILE_EXT
         fi
         curl $TLS -fgLo $DIFW_PATH/$UPGRADE_FILE $imageHTTPURL > $HTTP_CODE
         ret=$?
         if [ $ret -ne 0 ]; then
               swupdateLog "Local image Download Failed..Retrying"
               if [ $retryCount -ge $RETRY_COUNT ] ; then
                    swupdateLog "$RETRY_COUNT tries failed. Giving up local download"
               fi
         else
             break
         fi
     done
     return $ret
}

updateTargetImage()
{
     dnldImageName="$1.bin"
     getBuildType                                                        
     touch $dnldInProgressFlag
     # Download image from server to device
     downloadImage $dnldImageName
     resp=$?
     http_code=$(awk -F\" '{print $1}' $HTTP_CODE)

     if [ $resp -ne 0 ] || [ "$http_code" != "200" ]; then
          swupdateLog "Check the image in the CDL server"
          swupdateLog "Failed to download image with ret:$resp, httpcode:$http_code"
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
          
             updateFWDownloadStatusLog "Failure" "$failureReason" " " "$dnldFileName" "$runtime" "$(getFWVersion)" "$currentFlashedFileName" 
          else
             updateFWDownloadStatusLog "Failure" "Image download failed from server" " " "$dnldFileName" "$runtime" "$(getFWVersion)" "$currentFlashedFileName"
          fi

          rm -f $dnldInProgressFlag
          exit 0
     fi

     updateFWDownloadStatusLog "Flashing In Progress" " " " " "$dnldFileName" "$runtime" "$(getFWVersion)" "$currentFlashedFileName" 
     swupdateLog "$UPGRADE_FILE Flashing In Progress"
     if [ -f /lib/rdk/imageFlasher.sh ];then
          /lib/rdk/imageFlasher.sh 2 $ImageDownloadURL $DIFW_PATH $dnldImageName
          ret=$?
     else
          swupdateLog "imageFlasher.sh is missing"
     fi
     swupdateLog "Completing the image flash wait..!"
     sync
     if [ $ret -eq 0 ] ; then
         swupdateLog "IP download is complete, Rebooting the box now\n"
         echo "$dnldFileName" > $FLASH_FILE_NAME
         updateFWDownloadStatusLog "Success" " " "$(getServerImageName)" "$dnldFileName" "$runtime" "$(getFWVersion)" "$currentFlashedFileName" 
     else 
         updateFWDownloadStatusLog "Failure" "Failed in flash write " " " "$dnldFileName" "$runtime" "$(getFWVersion)" "$currentFlashedFileName" 

     fi
     rm -f $dnldInProgressFlag
     sh /rebootNow.sh -s UpgradeReboot_"`basename $0`" -o "Rebooting the box after Firmware Image Upgrade..."
     sync
}

getServerImageName()
{
    cat $DIFW_PATH/$(getMocaMacAddress).conf
}

### main app
if [ -f /tmp/wifi-on ]; then
    interface=`getWiFiInterface`
else
    interface=`getMoCAInterface`
fi

getServerFWVersion=""
fileName=""
currentFlashedFileName=""

if [ -f $FLASH_FILE_NAME ]; then
    currentFlashedFileName=`cat $FLASH_FILE_NAME`
fi

estbIp=`getIPAddress`
runtime=`date -u +%F' '%T`

# wait for the box to acquire IP address
while [ "$estbIp" = "" ] ; 
do         
    sleep 1                                  
    estbIp=`getIPAddress`
    swupdateLog "sleeping for ip"
done;


if [ "$estbIp" != "" ] ; then
    swupdateLog "--------- $interface got an ip $estbIp"
    ## collect the following data
    # current FW version from version
    swupdateLog "version = $(getFWVersion)"
    ###echo xreHost = $(getXREHost)
    swupdateLog "buildtype = $(getBuildType)"
    mocaMacAddr=$(getMocaMacAddress)
    swupdateLog "macAddr= $mocaMacAddr"
    getHTTPaddr
    rm -rf $DIFW_PATH/$mocaMacAddr.conf
    getBuildType
    swupdateLog "URL=$httpURL"
    swupdateLog "getting the macadress.conf file from http server"

    retry=1
    ret=1
    while [ $ret -ne 0 ] && [ $retry -ne 3 ]; do
        swupdateLog "Local image name download using MAC address Config, retry:$retry"
        curl $TLS -fgLo $DIFW_PATH/$mocaMacAddr.conf $httpURL/$SVR_MAC_ADDRESS_LOCATION/$mocaMacAddr.conf
        ret=$?
        retry=`expr $retry + 1`
        swupdateLog "ret=$ret"
    done
    if [ $ret -ne 0 ]; then
        swupdateLog "Local image name download using MAC address Config Failed on retry Giving up local download"
        exit 0
    fi
    swupdateLog "Local image name download using MAC address Config Completed"
    sync
    sleep 10
    swupdateLog "$(getServerImageName)"
    fileName=$(getServerImageName)
    dnldFileName="$fileName.bin"
    swupdateLog "get server image version= $(getServerImageName)"
    swupdateLog "get box image version= $(getFWVersion)"
    swupdateLog "get box previous downloaded image version= $(getPreviousDnldFWVersion)"
    ## Check if firmware download triggered by other means is in progress
    if [ -f $STATUS_FILE ]; then
        status=`cat $STATUS_FILE | grep "Status" | cut -d '|' -f2`
	## Check whether status is false status persisted during power cycle in between download.
	## Other means of image ugrade may need to create this flag to check for power cycle between download state
	if [ "$status" == "$UPGRADE_IN_PROGRESS_STRING1" ] || [  "$status" == "$UPGRADE_IN_PROGRESS_STRING2" ]; then
	    if [ -f $dnldInProgressFlag ]; then
	        swupdateLog "Previous initiated firmware upgrade in progress."
                updateFWDownloadStatusLog "Failure" "Previous Upgrade In Progress" " " "$dnldFileName" "$runtime" "$(getFWVersion)" "$currentFlashedFileName" 
    	        exit 0
	    fi
	 fi
    fi

     # Send query to the cloud - retry 3 times in case of failure
    if [ "$fileName" != "" ] ; then
        if [ "$(getServerImageName)" !=  "$(getFWVersion)" ] && [ "$(getServerImageName)" !=  "$(getPreviousDnldFWVersion)" ] ; then
            updateFWDownloadStatusLog "Download In Progress" " " " " "$dnldFileName" "$runtime" "$(getFWVersion)" "$currentFlashedFileName" 
 	    updateTargetImage $fileName
        else
	    swupdateLog "FW Versions or previous downloaded versions are same, no need to download"
            updateFWDownloadStatusLog "Failure" "Versions Match" "$(getServerImageName)" "$dnldFileName" "$runtime" "$(getFWVersion)" "$currentFlashedFileName"
            rm -f $dnldInProgressFlag 
     	fi
    else
	swupdateLog "Empty image name from CDL server"
        updateFWDownloadStatusLog "Failure" "Empty image name from CDL server" "$(getServerImageName)" "$dnldFileName" "$runtime" "$(getFWVersion)" "$currentFlashedFileName" 
        rm -f $dnldInProgressFlag
    fi	
fi


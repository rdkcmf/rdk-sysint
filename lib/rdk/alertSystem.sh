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

SCRIPT_NAME=`basename $0`

# Arguments count check
if [ "$#" -ne 2 ]; then
  echo "**************************************************"
  echo "Usage: $SCRIPT_NAME <Process Name> <Alert Message>"
  echo "**************************************************"
  exit 1
fi

# Argument Assigment
MSG_DATA=$2
PROCESS_NAME=$1

# Setup the config File
if [ -f /etc/device.properties ];then
     . /etc/device.properties
fi

# Utility script for getting MAC address utilities
if [ -f /lib/rdk/utils.sh ];then
     . /lib/rdk/utils.sh
fi

# Configuration Files
VERSION=1
HTTP_CODE="/tmp/splunkHttpCode"
HTTP_FILENAME="/tmp/splunkHttpOutput"
SPLUNK_URL_CACHE="/tmp/.splunk_end_point"
TELEMETRY_PROFILE_DEFAULT_PATH="/tmp/DCMSettings.conf"

currentTime=`date '+%Y-%m-%d %H:%M:%S'`
echo "$SCRIPT_NAME: $currentTime"

# Check if we are using https servers
if [ -s $SPLUNK_URL_CACHE ]; then
    splunkServer=`cat $SPLUNK_URL_CACHE`
else
    if [ -f $TELEMETRY_PROFILE_DEFAULT_PATH ]; then
        splunkServer=`grep '"uploadRepository:URL":"' $TELEMETRY_PROFILE_DEFAULT_PATH | awk -F 'uploadRepository:URL":' '{print $NF}' | awk -F '",' '{print $1}' | sed 's/"//g' | sed 's/}//g'`
        if [ ! -z "$splunkServer" ]; then
            echo "$splunkServer" > $SPLUNK_URL_CACHE
        else
            echo "$SCRIPT_NAME: Empty Splunk Server Address: $splunkServer from $TELEMETRY_PROFILE_DEFAULT_PATH"
        fi
    else
        echo "$SCRIPT_NAME: $TELEMETRY_PROFILE_DEFAULT_PATH, File Not Found"
    fi
fi

# Override for automated tests in non prod builds
if [ -f $PERSISTENT_PATH/splunk.conf ] && [ $BUILD_TYPE != "prod" ] ; then
    splunkServer=`cat $PERSISTENT_PATH/splunk.conf | tr -d ' '`
fi

# Override using RFC
splunkServer=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.DcaUploadUrl 2>&1)
if [ -z "$splunkServer" ]; then
    # Empty server details !!! Add default values
    . /etc/dcm.properties
    splunkServer="$DCA_UPLOAD_URL"   
fi

# Do minimum preprocessing if required on messages to avoid
if [ "$DEVICE_TYPE" = "hybrid" ];then
      estb_mac=`ifconfig -a $ESTB_INTERFACE | grep $ESTB_INTERFACE | tr -s ' ' | cut -d ' ' -f5 | tr -d '\r\n' | tr '[a-z]' '[A-Z]'`
else
      estb_mac=$(getEstbMacAddress)
fi
software_version=`grep ^imagename: /version.txt | cut -d ':' -f2`
EnableOCSPStapling="/tmp/.EnableOCSPStapling"
EnableOCSP="/tmp/.EnableOCSPCA"

strjson="{\"searchResult\":[{\"process_name\":\"$PROCESS_NAME\"},{\"mac\":\"$estb_mac\"},{\"Version\":\"$software_version\"},{\"msgTime\":\"$currentTime\"},{\"logEntry\":\"$MSG_DATA\"}]}"
if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
    CURL_CMD="curl -w '%{http_code}\n' -H \"Accept: application/json\" -H \"Content-type: application/json\" -X POST -d '$strjson' -o \"$HTTP_FILENAME\" \"$splunkServer\" --cert-status --connect-timeout 30 -m 30 "
else
    CURL_CMD="curl -w '%{http_code}\n' -H \"Accept: application/json\" -H \"Content-type: application/json\" -X POST -d '$strjson' -o \"$HTTP_FILENAME\" \"$splunkServer\" --connect-timeout 30 -m 30 "
fi

echo "$SCRIPT_NAME: CURL_CMD : $CURL_CMD"
eval $CURL_CMD > $HTTP_CODE
ret=$?
http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
echo "$SCRIPT_NAME: Return Status: $ret, HTTP CODE:$http_code"

if [ "$ret" -eq "0" ] && [ "$http_code" -eq "200" ]; then
    #Upload success
    exit 0
else
    #Upload failed
    exit 1
fi

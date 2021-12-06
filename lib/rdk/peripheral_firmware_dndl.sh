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

if [ -f /etc/env_setup.sh ]; then
    . /etc/env_setup.sh
fi

# override env if rfc desires so
if [ -f /lib/rdk/rfcOverrides.sh ]; then
    . /lib/rdk/rfcOverrides.sh
fi

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

if [ ! -f /etc/os-release ]; then
    IARM_EVENT_BINARY_LOCATION=/usr/local/bin
else
    IARM_EVENT_BINARY_LOCATION=/usr/bin
fi

#Set logs folder
if [ -z $LOG_PATH ]; then
    LOG_PATH="/opt/logs/"
fi

#Define variable for the peripheral image upgrade
TLS_LOG_FILE="$LOG_PATH/tlsError.log"
peripheral_json_file="$RAMDISK_PATH/rc-proxy-params.json"
CURL_TLS_TIMEOUT=30
CURRENT_PERIPHERAL_VERSION="/tmp/current_peripheral_versions.txt"
DOWNLOADED_PERIPHERAL_VERSION="/tmp/downloaded_peripheral_versions.txt"
HTTP_CODE="/tmp/peripheral_curl_httpcode"
mTlsXConfDownload="false"

#notifications to be send to Control Manager only atleast one download is successful
#holds the firmwares that are successfully downloaded
send_iarm_event=false
iarmevent_firmware_filenames=""

#Retry Logic setting for Codebig/Direct connection
MAX_RETRIES=3
CB_MAX_RETRIES=1
DIRECT_BLOCK_FILENAME="/tmp/.lastdirectfail_peridl"
CB_BLOCK_FILENAME="/tmp/.lastcodebigfail_peridl"

#Use log framework to print timestamp and source script name
swupdateLog()
{
    echo "`/bin/timestamp`: $0: $*"
}

tlsLog()
{
    echo "$0: $*" >> $TLS_LOG_FILE
}

IsDirectBlocked()
{
    directret=0
    if [ -f $DIRECT_BLOCK_FILENAME ]; then
        modtime=$(($(date +%s) - $(date +%s -r $DIRECT_BLOCK_FILENAME)))
        remtime=$((($DIRECT_BLOCK_TIME/3600) - ($modtime/3600)))
        if [ "$modtime" -le "$DIRECT_BLOCK_TIME" ]; then
            swupdateLog "peri_firmware_dndl: Last direct failed blocking is still valid for $remtime hrs, preventing direct"
            directret=1
        else
            swupdateLog "peri_firmware_dndl: Last direct failed blocking has expired, removing $DIRECT_BLOCK_FILENAME, allowing direct"
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
        cbremtime=$((($CB_BLOCK_TIME/60) - ($modtime/60)))
        if [ "$modtime" -le "$CB_BLOCK_TIME" ]; then
            swupdateLog "peri_firmware_dndl: Last Codebig failed blocking is still valid for $cbremtime mins, preventing Codebig"
            codebigret=1
        else
            swupdateLog "peri_firmware_dndl: Last Codebig failed blocking has expired, removing $CB_BLOCK_FILENAME, allowing Codebig"
            rm -f $CB_BLOCK_FILENAME
        fi
    fi
    return $codebigret
}

#retrieves the current firmware info of peripheral devices
getRemoteInfo()
{
    peripheral_data=""
    currentversions=""
    if [ -f $peripheral_json_file ]; then
        while read line
        do
            product_check=`echo $line | grep -c 'Product'`
            if [ $product_check -ne 0 ]; then
                peripheral_product=`echo $line | awk -F '"Product":"' '{print $NF}' | awk -F '"' '{print $1}'`
                peripheral_fw_version=`echo $line | awk -F '"FwVer":"' '{print $NF}' | awk -F '"' '{print $1}'`
                peripheral_audio_version=`echo $line | grep "AudioVer" | awk -F '"AudioVer":"' '{print $NF}' | awk -F '"' '{print $1}'`
                peripheral_dsp_version=`echo $line | grep "DspVer" | awk -F '"DspVer":"' '{print $NF}' | awk -F '"' '{print $1}'`
                peripheral_kw_model_version=`echo $line | grep "KwModelVer" | awk -F '"KwModelVer":"' '{print $NF}' | awk -F '"' '{print $1}'`
                peripheral_data="$peripheral_data&remCtrl$peripheral_product=$peripheral_fw_version"
                currentversions="${currentversions},${peripheral_product}_firmware_${peripheral_fw_version}.tgz"
                if [ ! -z $peripheral_audio_version ]; then
                    peripheral_data="$peripheral_data&remCtrlAudio$peripheral_product=$peripheral_audio_version"
                    currentversions="${currentversions},${peripheral_product}_audio_${peripheral_audio_version}.tgz"
                fi
                if [ ! -z $peripheral_dsp_version ]; then
                    peripheral_data="$peripheral_data&remCtrlDsp$peripheral_product=$peripheral_dsp_version"
                    currentversions="${currentversions},${peripheral_product}_dsp_${peripheral_dsp_version}.tgz"
                fi
                if [ ! -z $peripheral_kw_model_version ]; then
                    peripheral_data="$peripheral_data&remCtrlKwModel$peripheral_product=$peripheral_kw_model_version"
                    currentversions="${currentversions},${peripheral_product}_kw_model_${peripheral_kw_model_version}.tgz"
                fi
            fi
        done < $peripheral_json_file
    fi
    echo $currentversions > $CURRENT_PERIPHERAL_VERSION
    echo $peripheral_data
}

#sends notification to Control Manager with downloaded firmwares and their location 
sendNotification()
{
    if [ -f $IARM_EVENT_BINARY_LOCATION/IARM_event_sender ]; then
        $IARM_EVENT_BINARY_LOCATION/IARM_event_sender "PeripheralUpgradeEvent" "$DIFW_PATH" "$iarmevent_firmware_filenames"
    else
        swupdateLog "Missing the binary $IARM_EVENT_BINARY_LOCATION/IARM_event_sender"
    fi
}

#created the signed URL for codebig communication
getCodebigSignedURL()
{
    DAC15_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Sysint.DAC15CDLUrl 2>&1)
    if [ -z "$DAC15_URL" ]; then
        DAC15_URL="dac15cdlserver.ae.ccp.xcal.tv" 
    fi

    CURL_PARAMETER=""
    domainName=`echo $URL | awk -F/ '{print $3}'`
    CBURL=`echo $URL | sed -e "s|.*$domainName||g"`
    request_type=1

    if [ "$domainName" == "$DAC15_URL" ]; then
        request_type=14
    fi

    SIGN_CMD="GetServiceUrl $request_type \"$CBURL\""
    eval $SIGN_CMD > /tmp/.signedRequest
    if [ -s /tmp/.signedRequest ]
    then
        swupdateLog "GetServiceUrl success"
    else
        swupdateLog "GetServiceUrl failed"
        exit 1
    fi
    cbSignedURL=`cat /tmp/.signedRequest`
    rm -f /tmp/.signedRequest
    cbSignedURL=$(sed 's|stb_cdl%2F|stb_cdl/|g' <<< $cbSignedURL)
    authorizationHeader=`echo $cbSignedURL | sed -e "s|&|\", |g" -e "s|=|=\"|g" -e "s|.*oauth_consumer_key|oauth_consumer_key|g"`
    authorizationHeader="Authorization: OAuth realm=\"\", $authorizationHeader\""

    # getting codebig URL and authorisation header
    cbSignedURL=`echo $cbSignedURL | sed -e "s|&oauth_consumer_key.*||g"`
    CURL_PARAMETER="-H '$authorizationHeader'"
}

#Function to download the cloud firmware, uses TLS or Codebig for the connection.
#Common for both Direct communication and Codebig communication
sendTLSRequestForImageDownload()
{
    URL="$upgrade_location/$firmware_version.tgz"
    # check whether communication is codebig. if codebig, then gets the signed URL and authorization header
    EnableOCSPStapling="/tmp/.EnableOCSPStapling"
    EnableOCSP="/tmp/.EnableOCSPCA"

    # MTLS flag to use secure endpoints
    if [ "$DEVICE_TYPE" = "hybrid" ] || [ "$DEVICE_TYPE" = "mediaclient" ]; then
        mTlsXConfDownload=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.MTLS.mTlsXConfDownload.Enable 2>&1 > /dev/null)
        if [ "$FORCE_MTLS" == "true" ]; then
            swupdateLog "MTLS method enabled"
            mTlsXConfDownload="true"
        fi
    fi

    if [ "$UseCodebig" -eq 1 ]; then
       getCodebigSignedURL
       if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
            cmd="curl $TLS --cert-status --connect-timeout $CURL_TLS_TIMEOUT -w '%{http_code}\n' $CURL_PARAMETER -fgLo $DIFW_PATH/$firmware_version.tgz \"$cbSignedURL\""
        else
           cmd="curl $TLS --connect-timeout $CURL_TLS_TIMEOUT -w '%{http_code}\n' $CURL_PARAMETER -fgLo $DIFW_PATH/$firmware_version.tgz \"$cbSignedURL\""
        fi
    else
        #RDK-32180: Use mTLS for Xconf/SSR Interaction for BLE Remote Control Firmware Upgrade
        if [ "$mTlsXConfDownload" == "true" ]; then
            swupdateLog "Peripheral Upgrade requires Mutual Authentication"
            if [ -d /etc/ssl/certs ]; then
                if [ ! -f /usr/bin/GetConfigFile ];then
                    swupdateLog "Error: GetConfigFile Not Found"
                    exit 127
                fi
                ID="/tmp/uydrgopwxyem"
                GetConfigFile $ID
            fi
            CERT=" --key /tmp/uydrgopwxyem --cert /etc/ssl/certs/cpe-clnt.xcal.tv.cert.pem"
            cmd="curl $TLS$CERT --connect-timeout $CURL_TLS_TIMEOUT -w '%{http_code}\n' -fgLo $DIFW_PATH/$firmware_version.tgz \"$URL\""
        else
            cmd="curl $TLS --connect-timeout $CURL_TLS_TIMEOUT -w '%{http_code}\n' -fgLo $DIFW_PATH/$firmware_version.tgz \"$URL\""
        fi

        if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
            cmd="$cmd  --cert-status"
        fi    
    fi
    swupdateLog "Download URL: $cmd"

    eval $cmd > $HTTP_CODE
    TLSRet=$?
    case $TLSRet in
        35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
            tlsLog "HTTPS $TLS failed to connect to SSR server with curl error code $TLSRet" >> $LOG_PATH/tlsError.log
        ;;
    esac
    swupdateLog "Curl download return code : $TLSRet"

    if [ -f "$ID" ];then
        rm -rf $ID
    else
        swupdateLog "MTLS method not enabled"
    fi

    if [ "$TLSRet" = "7" ]; then
         t2CountNotify "swdl_failed_7"
    fi
}

downloadPeripheralFirmware()
{
    swupdateLog "Trying to download $firmware_version.tgz"
    sendTLSRequestForImageDownload
    http_code=$(awk -F\" '{print $1}' $HTTP_CODE)

    if [ $TLSRet -eq 0 ] && [ "$http_code" = "200" ]; then
        swupdateLog "Downloading $firmware_version.tgz is successful"
        # !! Have to stick with this message format as current dashboard is expecting this data !!
        t2ValNotify "xr_fwdnld_split" "${firmware_version:2}.tgz is successful"
        previous_downloadversions="${previous_downloadversions},${firmware_version}.tgz"
        if [ "$downloaded_version" != "" ]; then
            previous_downloadversions=`echo $previous_downloadversions | sed "s/,$downloaded_version//g"`
        fi

        send_iarm_event=true
        if [ "$iarmevent_firmware_filenames" == "" ]; then
            iarmevent_firmware_filenames=$firmware_version".tgz"
        else
            iarmevent_firmware_filenames=$iarmevent_firmware_filenames","$firmware_version".tgz"
        fi
    else
        swupdateLog "Downloading $firmware_version.tgz failed"
    fi
}

#parses the input and trigger download for each firmware,
#Also switches to Codebig if Direct fails
getPeripheralFirmwares()
{
    swupdateLog "Going to download peripheral firmwares"
    # Cleaning up the variable
    iarmevent_firmware_filenames="" 
    ret=0
    retries=0
    cbretries=0
    upgrade_location=$1
    peripheral_firmwares=$2
    TLS="--tlsv1.2"
    UseCodebig=$3
    count=1
    currentversions=`cat $CURRENT_PERIPHERAL_VERSION`
    cloud_fw_is_lower_version=0
    cloud_and_current_fw_versions_same=0
    if [ -f $DOWNLOADED_PERIPHERAL_VERSION ]; then
        previous_downloadversions=`cat $DOWNLOADED_PERIPHERAL_VERSION`
    fi
    swupdateLog "getPeripheralFirmwares(): Received DL request for = $peripheral_firmwares"
    firmware_version=`echo $peripheral_firmwares | cut -d "," -f1`
    swupdateLog "getPeripheralFirmwares(): Current FW = $currentversions"
    swupdateLog "getPeripheralFirmwares(): FW to be downloaded =  $firmware_version"

    if [ ! -d $DIFW_PATH ]; then
        mkdir -p $DIFW_PATH
    fi
    
    while [ "$firmware_version" != "" ]
    do
        trigger_download=1
        peripheral_device_type=`echo $firmware_version | cut -d "_" -f1`
        peripheral_version_type=`echo $firmware_version | cut -d "_" -f2`

        swupdateLog "Deleting the Old $peripheral_device_type $peripheral_version_type tar files if any"
        if [ ! -e $DIFW_PATH/$firmware_version.tgz ];then
             rm -rf $DIFW_PATH/${peripheral_device_type}_${peripheral_version_type}_*.tgz
             swupdateLog "Deleted $DIFW_PATH/${peripheral_device_type}_${peripheral_version_type}_*.tgz"
        fi

        if [ "$currentversions" != "" ]; then
            image_check=`echo $currentversions | tr "," "\n" | grep "$peripheral_device_type" | grep "$peripheral_version_type" | grep -v "$firmware_version"`
            swupdateLog "getPeripheralFirmwares(): ImageCheck = $image_check"

            if [ "$image_check" == "" ]; then
                 trigger_download=0
                 swupdateLog "getPeripheralFirmwares(): ImageCheck is empty Not triggering DL"
            fi
        fi

        if [ "$previous_downloadversions" != "" ]; then
            swupdateLog "getPeripheralFirmwares(): PrevDownload Version = $previous_downloadversions"
            downloaded_version=`echo $previous_downloadversions | tr "," "\n" | grep "$peripheral_device_type" | grep "$peripheral_version_type"`
            if [[ "$downloaded_version" == "$firmware_version.tgz" ]] ; then
                swupdateLog "getPeripheralFirmwares: Prev Downloaded FW($downloaded_version) and Cur FW($firmware_version) are Same"
                trigger_download=0
                cloud_and_current_fw_versions_same=1
            fi
        fi

        peripheral_version_number=`echo $firmware_version | cut -d "_" -f3`
        current_version_number=`echo $currentversions | tr "," "\n" | grep "$peripheral_device_type" | grep "$peripheral_version_type" | grep -v "$firmware_version"`
        current_version_number=`echo $current_version_number | cut -d "_" -f3`
        current_version_number=echo ${current_version_number%.*}
        peripheral_version_digit=0
        current_version_digit=0
        version_digit_count=1
        while [[ "$peripheral_version_digit" != "" && "$current_version_digit" != "" && $trigger_download -ne 0 ]]
        do
          peripheral_version_digit=`echo $peripheral_version_number | cut -d "." -f$version_digit_count`
          current_version_digit=`echo $current_version_number | cut -d "." -f$version_digit_count`
          if [[ $peripheral_version_digit -gt $current_version_digit ]]; then
               break
          elif [[ $peripheral_version_digit -lt $current_version_digit ]]; then
               trigger_download=0
               cloud_fw_is_lower_version=1
               break
          fi
          version_digit_count=`expr $version_digit_count + 1`
        done

        if [ $trigger_download -eq 1 ] ; then
            ret=1
            if [ $UseCodebig -eq 1 ]; then
                swupdateLog "getPeripheralFirmwares: Codebig is enabled UseCodebig:$UseCodebig" 
                if [ "$DEVICE_TYPE" = "mediaclient" ]; then
                    # Use Codebig connection connection on XI platforms
                    IsCodeBigBlocked
                    skipcodebig=$?
                    if [ $skipcodebig -eq 0 ]; then
                        while [ "$cbretries" -le $CB_MAX_RETRIES ]
                        do
                            swupdateLog "getPeripheralFirmwares: Attempting Codebig firmware download" 
                            downloadPeripheralFirmware
                            http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                            if [ "$http_code" = "200" ]; then
                                swupdateLog "getPeripheralFirmwares: Codebig firmware download Success: httpcode=$http_code" 
                                IsDirectBlocked
                                skipDirect=$?
                                if [ $skipDirect -eq 0 ]; then
                                    UseCodebig=0
                                fi
                                break
                            elif [ "$http_code" = "404" ]; then
                                swupdateLog "getPeripheralFirmwares: Received 404 response for Codebig firmware download, Retry logic not needed"
                                break
                            fi
                            swupdateLog "getPeripheralFirmwares: Codebig firmware download return: retry=$cbretries, httpcode=$http_code" 
                            cbretries=`expr $cbretries + 1`
                            sleep 10
                        done
                    fi

                    if [ "$http_code" = "000" ];then
                        IsDirectBlocked
                        skipdirect=$?
                        if [ $skipdirect -eq 0 ]; then
                            swupdateLog "getPeripheralFirmwares: Codebig firmware download failed: httpcode=$http_code, Using Direct" 
                            UseCodebig=0
                            downloadPeripheralFirmware
                            http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                            if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                                swupdateLog "getPeripheralFirmwares: Direct firmware download request failover failed: httpcode=$http_code" 
                            else
                                swupdateLog "getPeripheralFirmwares: Direct firmware download request failover received: httpcode=$http_code" 
                            fi
                        fi
                        IsCodeBigBlocked
                        skipCodeBig=$?
                        if [ $skipCodeBig -eq 0 ]; then
                            swupdateLog "getPeripheralFirmwares: Codebig block released" 
                        fi
                    elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                        swupdateLog "getPeripheralFirmwares: Codebig firmware download failed with httpcode=$http_code"
                    fi
                else
                    swupdateLog "getPeripheralFirmwares: Codebig is not supported"
                fi
            else
                swupdateLog "getPeripheralFirmwares: Codebig is disabled UseCodebig=$UseCodebig"
                IsDirectBlocked
                skipdirect=$?
                if [ $skipdirect -eq 0 ]; then
                    while [ "$retries" -lt $MAX_RETRIES ]
                    do
                       swupdateLog "getPeripheralFirmwares: Attempting Direct firmware download" 
                       downloadPeripheralFirmware
                       http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                       if [ "$http_code" = "200" ];then
                           swupdateLog "getPeripheralFirmwares: Direct firmware download success: httpcode=$http_code" 
                           break
                       elif [ "$http_code" = "404" ]; then
                           swupdateLog "getPeripheralFirmwares: Received 404 response for Direct firmware download, Retry logic not needed"
                           break
                       fi
                       swupdateLog "getPeripheralFirmwares: Direct firmware download return: retry=$retries, httpcode=$http_code" 
                       retries=`expr $retries + 1`
                       sleep 60
                    done
                fi
        
                if [ "$http_code" = "000" ]; then 
                    if [ "$DEVICE_TYPE" = "mediaclient" ]; then
                        swupdateLog "getPeripheralFirmwares: Direct firmware download failed: httpcode=$http_code, Using Codebig" 
                        IsCodeBigBlocked
                        skipcodebig=$?
                        if [ $skipcodebig -eq 0 ]; then
                            while [ "$cbretries" -le $CB_MAX_RETRIES ]
                            do
                                UseCodebig=1
                                downloadPeripheralFirmware
                                http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                                if [ "$http_code" = "200" ]; then
                                    swupdateLog "getPeripheralFirmwares: Codebig firmware download success: httpcode=$http_code" 
                                    UseCodebig=1
                                    if [ ! -f $DIRECT_BLOCK_FILENAME ]; then
                                        touch $DIRECT_BLOCK_FILENAME
                                        swupdateLog "getPeripheralFirmwares: Use Codebig and Block Direct for 24 hrs "
                                    fi
                                    break
                                elif [ "$http_code" = "404" ]; then
                                    swupdateLog "getPeripheralFirmwares: Received 404 response for Codebig firmware download, Retry logic not needed"
                                    break
                                fi
                                swupdateLog "getPeripheralFirmwares: Codebig firmware download return: retry=$cbretries, http code=$http_code" 
                                cbretries=`expr $cbretries + 1`
                                sleep 60
                            done

                            if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                                swupdateLog "getPeripheralFirmwares: Codebig firmware download failed: httpcode=$http_code" 
                                UseCodebig=0
                                if [ ! -f $CB_BLOCK_FILENAME ]; then
                                    touch $CB_BLOCK_FILENAME
                                    swupdateLog "getPeripheralFirmwares: Switch Direct and Blocking Codebig for 30mins"
                                fi
                            fi
                        fi
                    else
                        swupdateLog "getPeripheralFirmwares: Codebig is not supported"
                    fi
                elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                    swupdateLog "getPeripheralFirmwares: Direct firmware download failed: httpcode=$http_code"
                fi
            fi
        elif [ $trigger_download -eq 0 ] && [ $cloud_and_current_fw_versions_same -eq 1 ]; then
            swupdateLog "getPeripheralFirmwares: Skipping download of $firmware_version, as current/downloaded image and cloud image are same"
        elif [ $trigger_download -eq 0 ] && [ $cloud_fw_is_lower_version -eq 1 ]; then
            swupdateLog "`/bin/timestamp`getPeripheralFirmwares: Skipping download of $firmware_version, as cloud fw image is lower version than current/downloaded fw image"
        fi

        if [ "$http_code" == "404" ] ; then
            swupdateLog "getPeripheralFirmwares: download of $firmware_version failed with HTTP 404 error"
        fi

        count=`expr $count + 1`
        firmware_version=`echo $peripheral_firmwares | cut -d "," -f$count`
        swupdateLog "getPeripheralFirmwares: Next FW to DL $firmware_version"
    done
    #send notification if atleast one download is successful
    if [ "$send_iarm_event" == "true" ]; then
        sendNotification
        ret=0
    fi
    echo $previous_downloadversions > $DOWNLOADED_PERIPHERAL_VERSION
    return $ret
}

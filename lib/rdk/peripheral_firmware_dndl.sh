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
. /etc/include.properties
. /etc/device.properties

# override env if rfc desires so
if [ -f /lib/rdk/rfcOverrides.sh ]; then
    . /lib/rdk/rfcOverrides.sh
fi

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

if [ -z $LOG_PATH ]; then
    LOG_PATH="/opt/logs/"
fi

#input file to get the peripheral image versions
peripheral_json_file="$RAMDISK_PATH/rc-proxy-params.json"
CURL_TLS_TIMEOUT=30
#notifications to be send to Control Manager only atleast one download is successful
send_iarm_event=false
#holds the firmwares that are successfully downloaded
iarmevent_firmware_filenames=""

CURRENT_PERIPHERAL_VERSION="/tmp/current_peripheral_versions.txt"
DOWNLOADED_PERIPHERAL_VERSION="/tmp/downloaded_peripheral_versions.txt"
HTTP_CODE="/tmp/peripheral_curl_httpcode"

MAX_RETRIES=3
CB_MAX_RETRIES=1
DIRECT_BLOCK_FILENAME="/tmp/.lastdirectfail_peridl"
CB_BLOCK_FILENAME="/tmp/.lastcodebigfail_peridl"

DAC15_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Sysint.DAC15CDLUrl 2>&1)
if [ -z "$DAC15_URL" ]; then
    DAC15_URL="dac15cdlserver.ae.ccp.xcal.tv" 
fi

if [ ! -f /etc/os-release ]; then
    IARM_EVENT_BINARY_LOCATION=/usr/local/bin
else
    IARM_EVENT_BINARY_LOCATION=/usr/bin
fi

IsDirectBlocked()
{
    directret=0
    if [ -f $DIRECT_BLOCK_FILENAME ]; then
        modtime=$(($(date +%s) - $(date +%s -r $DIRECT_BLOCK_FILENAME)))
        remtime=$((($DIRECT_BLOCK_TIME/3600) - ($modtime/3600)))
        if [ "$modtime" -le "$DIRECT_BLOCK_TIME" ]; then
            echo "`/bin/timestamp`peri_firmware_dndl: Last direct failed blocking is still valid for $remtime hrs, preventing direct"
            directret=1
        else
            echo "`/bin/timestamp`peri_firmware_dndl: Last direct failed blocking has expired, removing $DIRECT_BLOCK_FILENAME, allowing direct"
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
            echo "`/bin/timestamp`peri_firmware_dndl: Last Codebig failed blocking is still valid for $cbremtime mins, preventing Codebig"
            codebigret=1
        else
            echo "`/bin/timestamp`peri_firmware_dndl: Last Codebig failed blocking has expired, removing $CB_BLOCK_FILENAME, allowing Codebig"
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
        echo "Missing the binary $IARM_EVENT_BINARY_LOCATION/IARM_event_sender"
    fi
}

#created the signed URL for codebig communication
getCodebigSignedURL()
{
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
        echo "GetServiceUrl success"
    else
        echo "GetServiceUrl failed"
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

    if [ "$UseCodebig" -eq 1 ]; then
       getCodebigSignedURL
       if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
            cmd="curl $TLS --cert-status --connect-timeout $CURL_TLS_TIMEOUT -w '%{http_code}\n' $CURL_PARAMETER -fgLo $DIFW_PATH/$firmware_version.tgz \"$cbSignedURL\""
        else
           cmd="curl $TLS --connect-timeout $CURL_TLS_TIMEOUT -w '%{http_code}\n' $CURL_PARAMETER -fgLo $DIFW_PATH/$firmware_version.tgz \"$cbSignedURL\""
        fi
    else
        if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
            cmd="curl $TLS --cert-status --connect-timeout $CURL_TLS_TIMEOUT -w '%{http_code}\n' -fgLo $DIFW_PATH/$firmware_version.tgz \"$URL\""
        else
            cmd="curl $TLS --connect-timeout $CURL_TLS_TIMEOUT -w '%{http_code}\n' -fgLo $DIFW_PATH/$firmware_version.tgz \"$URL\""
        fi
    fi
    echo "Download URL: $cmd"
    eval $cmd > $HTTP_CODE
    TLSRet=$?

    case $TLSRet in
        35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
            echo "HTTPS $TLS failed to connect to SSR server with curl error code $TLSRet" >> $LOG_PATH/tlsError.log
        ;;
    esac

    echo "Curl download return code : $TLSRet"
    if [ "$TLSRet" = "7" ]; then
         t2CountNotify "swdl_failed_7"
    fi
}

downloadPeripheralFirmware()
{
    echo "Trying to download $firmware_version.tgz"
    sendTLSRequestForImageDownload
    http_code=$(awk -F\" '{print $1}' $HTTP_CODE)

    if [ $TLSRet -eq 0 ] && [ "$http_code" = "200" ]; then
        echo "Downloading $firmware_version.tgz is successful"
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
        echo "Downloading $firmware_version.tgz failed"
    fi
}

#parses the input and trigger download for each firmware,
#Also switches to Codebig if Direct fails
getPeripheralFirmwares()
{

    echo "Going to download peripheral firmwares"
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
    if [ -f $DOWNLOADED_PERIPHERAL_VERSION ]; then
        previous_downloadversions=`cat $DOWNLOADED_PERIPHERAL_VERSION`
    fi
    echo "`/bin/timestamp` getPeripheralFirmwares(): Received DL request for = $peripheral_firmwares"
    firmware_version=`echo $peripheral_firmwares | cut -d "," -f1`
    
    echo "`/bin/timestamp` getPeripheralFirmwares(): Current FW = $currentversions"
    echo "`/bin/timestamp` getPeripheralFirmwares(): FW to be downloaded =  $firmware_version"

    if [ ! -d $DIFW_PATH ]; then
        mkdir -p $DIFW_PATH
    fi
    
    while [ "$firmware_version" != "" ]
    do
        trigger_download=1
        peripheral_device_type=`echo $firmware_version | cut -d "_" -f1`
        peripheral_version_type=`echo $firmware_version | cut -d "_" -f2`

        echo "Deleting the Old $peripheral_device_type $peripheral_version_type tar files if any"
        if [ ! -e $DIFW_PATH/$firmware_version.tgz ];then
             rm -rf $DIFW_PATH/${peripheral_device_type}_${peripheral_version_type}_*.tgz
             echo "Deleted $DIFW_PATH/${peripheral_device_type}_${peripheral_version_type}_*.tgz"
        fi

        if [ "$currentversions" != "" ]; then
            image_check=`echo $currentversions | tr "," "\n" | grep "$peripheral_device_type" | grep "$peripheral_version_type" | grep -v "$firmware_version"`
            echo "`/bin/timestamp` getPeripheralFirmwares(): ImageCheck = $image_check"

            if [ "$image_check" == "" ]; then
                 trigger_download=0
                 echo "`/bin/timestamp` getPeripheralFirmwares(): ImageCheck is empty Not triggering DL"
            fi
        fi

        if [ "$previous_downloadversions" != "" ]; then
            echo "`/bin/timestamp` getPeripheralFirmwares(): PrevDownload Version = $previous_downloadversions"
            downloaded_version=`echo $previous_downloadversions | tr "," "\n" | grep "$peripheral_device_type" | grep "$peripheral_version_type"`
            if [ "$downloaded_version" == "$firmware_version.tgz" ] ; then
                echo "`/bin/timestamp` getPeripheralFirmwares: Prev Downloaded FW($downloaded_version) and Cur FW($firmware_version) are Same"
                trigger_download=0
            fi
        fi

        if [ $trigger_download -eq 1 ] ; then
            ret=1
            if [ $UseCodebig -eq 1 ]; then
                echo "`/bin/timestamp`getPeripheralFirmwares: Codebig is enabled UseCodebig:$UseCodebig" 
                if [ "$DEVICE_TYPE" = "mediaclient" ]; then
                    # Use Codebig connection connection on XI platforms
                    IsCodeBigBlocked
                    skipcodebig=$?
                    if [ $skipcodebig -eq 0 ]; then
                        while [ "$cbretries" -le $CB_MAX_RETRIES ]
                        do
                            echo "`/bin/timestamp`getPeripheralFirmwares: Attempting Codebig firmware download" 
                            downloadPeripheralFirmware
                            http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                            if [ "$http_code" = "200" ]; then
                                echo "`/bin/timestamp`getPeripheralFirmwares: Codebig firmware download Success: httpcode=$http_code" 
                                IsDirectBlocked
                                skipDirect=$?
                                if [ $skipDirect -eq 0 ]; then
                                    UseCodebig=0
                                fi
                                break
                            elif [ "$http_code" = "404" ]; then
                                echo "`/bin/timestamp`getPeripheralFirmwares: Received 404 response for Codebig firmware download, Retry logic not needed"
                                break
                            fi
                            echo "`/bin/timestamp`getPeripheralFirmwares: Codebig firmware download return: retry=$cbretries, httpcode=$http_code" 
                            cbretries=`expr $cbretries + 1`
                            sleep 10
                        done
                    fi

                    if [ "$http_code" = "000" ];then
                        IsDirectBlocked
                        skipdirect=$?
                        if [ $skipdirect -eq 0 ]; then
                            echo "`/bin/timestamp`getPeripheralFirmwares: Codebig firmware download failed: httpcode=$http_code, Using Direct" 
                            UseCodebig=0
                            downloadPeripheralFirmware
                            http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                            if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                                echo "`/bin/timestamp`getPeripheralFirmwares: Direct firmware download request failover failed: httpcode=$http_code" 
                            else
                                echo "`/bin/timestamp`getPeripheralFirmwares: Direct firmware download request failover received: httpcode=$http_code" 
                            fi
                        fi
                        IsCodeBigBlocked
                        skipCodeBig=$?
                        if [ $skipCodeBig -eq 0 ]; then
                            echo "`/bin/timestamp`getPeripheralFirmwares: Codebig block released" 
                        fi
                    elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                        echo "`/bin/timestamp`getPeripheralFirmwares: Codebig firmware download failed with httpcode=$http_code"
                    fi
                else
                    echo "`/bin/timestamp`getPeripheralFirmwares: Codebig is not supported"
                fi
            else
                echo "`/bin/timestamp`getPeripheralFirmwares: Codebig is disabled UseCodebig=$UseCodebig"
                IsDirectBlocked
                skipdirect=$?
                if [ $skipdirect -eq 0 ]; then
                    while [ "$retries" -lt $MAX_RETRIES ]
                    do
                       echo "`/bin/timestamp`getPeripheralFirmwares: Attempting Direct firmware download" 
                       downloadPeripheralFirmware
                       http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                       if [ "$http_code" = "200" ];then
                           echo "`/bin/timestamp`getPeripheralFirmwares: Direct firmware download success: httpcode=$http_code" 
                           break
                       elif [ "$http_code" = "404" ]; then
                           echo "`/bin/timestamp`getPeripheralFirmwares: Received 404 response for Direct firmware download, Retry logic not needed"
                           break
                       fi
                       echo "`/bin/timestamp`getPeripheralFirmwares: Direct firmware download return: retry=$retries, httpcode=$http_code" 
                       retries=`expr $retries + 1`
                       sleep 60
                    done
                fi
        
                if [ "$http_code" = "000" ]; then 
                    if [ "$DEVICE_TYPE" = "mediaclient" ]; then
                        echo "`/bin/timestamp`getPeripheralFirmwares: Direct firmware download failed: httpcode=$http_code, Using Codebig" 
                        IsCodeBigBlocked
                        skipcodebig=$?
                        if [ $skipcodebig -eq 0 ]; then
                            while [ "$cbretries" -le $CB_MAX_RETRIES ]
                            do
                                UseCodebig=1
                                downloadPeripheralFirmware
                                http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                                if [ "$http_code" = "200" ]; then
                                    echo "`/bin/timestamp`getPeripheralFirmwares: Codebig firmware download success: httpcode=$http_code" 
                                    UseCodebig=1
                                    if [ ! -f $DIRECT_BLOCK_FILENAME ]; then
                                        touch $DIRECT_BLOCK_FILENAME
                                        echo "`/bin/timestamp`getPeripheralFirmwares: Use Codebig and Block Direct for 24 hrs "
                                    fi
                                    break
                                elif [ "$http_code" = "404" ]; then
                                    echo "`/bin/timestamp`getPeripheralFirmwares: Received 404 response for Codebig firmware download, Retry logic not needed"
                                    break
                                fi
                                echo "`/bin/timestamp`getPeripheralFirmwares: Codebig firmware download return: retry=$cbretries, http code=$http_code" 
                                cbretries=`expr $cbretries + 1`
                                sleep 60
                            done

                            if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                                echo "`/bin/timestamp`getPeripheralFirmwares: Codebig firmware download failed: httpcode=$http_code" 
                                UseCodebig=0
                                if [ ! -f $CB_BLOCK_FILENAME ]; then
                                    touch $CB_BLOCK_FILENAME
                                    echo "`/bin/timestamp`getPeripheralFirmwares: Switch Direct and Blocking Codebig for 30mins"
                                fi
                            fi
                        fi
                    else
                        echo "`/bin/timestamp`getPeripheralFirmwares: Codebig is not supported"
                    fi
                elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                    echo "`/bin/timestamp`getPeripheralFirmwares: Direct firmware download failed: httpcode=$http_code"
                fi
            fi
        else
            echo "`/bin/timestamp`getPeripheralFirmwares: Skipping download of $firmware_version, as current/downloaded image and cloud image are same"
        fi

        if [ "$http_code" == "404" ] ; then
            echo "`/bin/timestamp`getPeripheralFirmwares: download of $firmware_version failed with HTTP 404 error"
        fi

        count=`expr $count + 1`
        firmware_version=`echo $peripheral_firmwares | cut -d "," -f$count`
        echo "`/bin/timestamp` getPeripheralFirmwares: Next FW to DL $firmware_version"
    done
    #send notification if atleast one download is successful
    if [ "$send_iarm_event" == "true" ]; then
        sendNotification
        ret=0
    fi
    echo $previous_downloadversions > $DOWNLOADED_PERIPHERAL_VERSION
    return $ret
}


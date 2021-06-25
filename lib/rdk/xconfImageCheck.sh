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
## Script to Check Firmware Update Status from XConf
##################################################################

. /etc/include.properties
. /etc/device.properties

if [ "$DEVICE_TYPE" == "mediaclient" ]; then
    . /etc/common.properties 
    if [ -f $RDK_PATH/utils.sh ]; then
       . $RDK_PATH/utils.sh
    fi
else
    if [ -f $RDK_PATH/commonUtils.sh ];then
       . $RDK_PATH/commonUtils.sh
    fi
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


## RETRY DELAY in secs
RETRY_COUNT_XCONF=0
RETRY_DELAY_XCONF=60
RETRY_SHORT_DELAY_XCONF=10

## RETRY COUNT
RETRY_COUNT=3
CB_RETRY_COUNT=1

## File to save curl/wget response
FILENAME="/tmp/xconf_response_thunder.txt"
## File to save http code and curl progress
HTTP_CODE="/tmp/xconf_httpcode_thunder.txt"

CURL_PROGRESS="/tmp/xconf_curl_progress_thunder"

## PDRI image filename
pdriFwVerInfo=""

## Timezone file for all platforms Gram/Fles boxes.
TIMEZONEDST="/opt/persistent/timeZoneDST"

WAREHOUSE_ENV="$RAMDISK_PATH/warehouse_mode_active"
## Capabilities of the current box
CAPABILITIES='&capabilities="rebootDecoupled"&capabilities="RCDL"&capabilities="supportsFullHttpUrl"'

## curl URL and options
ImageDownloadURL=""
imageHTTPURL=""
serverUrl=""
CB_SIGNED_REQUEST=""
CLOUD_URL=""
CURL_OPTION="-w"

## Status of each upgrade
pci_upgrade_status=1
pdri_upgrade_status=1
peripheral_upgrade_status=1

## stores timezone value
zoneValue=Universal

## Disable Forced HTTPS
DisableForcedHttps=false

#$ TLS values and timeouts
CURL_TLS_TIMEOUT=30
TLS="--tlsv1.2"
TLSRet=""
curl_result=1

DIRECT_BLOCK_FILENAME="/tmp/.lastdirectfail_cdl_thunder"
CB_BLOCK_FILENAME="/tmp/.lastcodebigfail_cdl_thunder"

EnableOCSPStapling="/tmp/.EnableOCSPStapling"
EnableOCSP="/tmp/.EnableOCSPCA"

if [ -z $LOG_PATH ]; then
    LOG_PATH="/opt/logs/"
fi

# Support Xconf override url from persistent path for non prod builds only
if [ -f $PERSISTENT_PATH/swupdate.conf ] && [ $BUILD_TYPE != "prod" ] ; then
    urlString=`grep -v '^[[:space:]]*#' $PERSISTENT_PATH/swupdate.conf`
    echo "$urlString" | grep -q -i "^http.*://"
    if [ $? -ne 0 ]; then
        echo "`Timestamp` Device configured with an invalid overriden URL : $urlString !!! Exiting from Image Upgrade process..!"
        exit 0
    fi
fi

# Autoupdate exclusion based on Xconf
Fwupdate_auto_exclude=`tr181 -D Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.FWUpdate.AutoExcluded.Enable 2>&1 > /dev/null`

# MTLS flag to use secure endpoints
mTlsXConfDownload=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.MTLS.mTlsXConfDownload.Enable 2>&1 > /dev/null)

if [ "$Fwupdate_auto_exclude" == "true" ] && [ $BUILD_TYPE != "prod" ] && [ ! $urlString ] ; then
    echo "Device excluded from firmware update. Exiting !!"
    exit 0
fi


if [ -f $CURL_PROGRESS ]; then
    rm $CURL_PROGRESS
fi

DisableForcedHttps=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.EnableHttpCDL.Enable 2>&1 > /dev/null`
echo "`Timestamp` RFC value for enabling HTTP download is : $DisableForcedHttps"

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
    return $codebigret
}

getaddressType()
{

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
}

sendTLSRequest()
{
    TLSRet=1
    echo "000" > $HTTP_CODE     # provide a default value to avoid possibility of an old value remaining

    if [ "$FORCE_MTLS" == "true" ]; then
        echo "MTLS prefered"
        mTlsXConfDownload="true"
    fi
    
    if [ "$1" == "XCONF" ]; then
        echo "Attempting $TLS connection to XCONF server"

        if [ "$mTLS_RPI" == "true" ] ; then
            CURL_CMD="curl -vv --cert-type pem --cert /etc/ssl/certs/refplat-xconf-cpe-clnt.xcal.tv.cert.pem --key /tmp/xconf-file.tmp -w '%{http_code}\n' -d \"$JSONSTR\" -o \"$FILENAME\" \"$CLOUD_URL\" --connect-timeout 10 -m 10"

        elif [ "$mTlsXConfDownload" == "true" ]; then
            if [ -d /etc/ssl/certs ]; then
                if [ ! -f /usr/bin/GetConfigFile ]; then
                    echo "Error: GetConfigFile Not Found"
                    exit 127
                fi
                ID="/tmp/uydrgopwxyem"
                GetConfigFile $ID
            fi
            CURL_CMD="curl $TLS --key /tmp/uydrgopwxyem --cert /etc/ssl/certs/cpe-clnt.xcal.tv.cert.pem --connect-timeout $CURL_TLS_TIMEOUT $CURL_OPTION '%{http_code}\n' -d \"$JSONSTR\" -o \"$FILENAME\" \"$CLOUD_URL\" -m 10"
        else
            CURL_CMD="curl $TLS --connect-timeout $CURL_TLS_TIMEOUT $CURL_OPTION '%{http_code}\n' -d \"$JSONSTR\" -o \"$FILENAME\" \"$CLOUD_URL\" -m 10"
        fi
        if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
           CURL_CMD="$CURL_CMD --cert-status"
        fi

        if [ "$BUILD_TYPE" != "prod" ]; then
           echo CURL_CMD: $CURL_CMD
        else 
           echo ADDITIONAL_FW_VER_INFO: $pdriFwVerInfo$remoteInfo
        fi
        result= eval $CURL_CMD > $HTTP_CODE

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
}


## get Server URL
getServURL()
{
    buildType=$(getBuildType)

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
            CLOUD_URL="https://ccpxcb-dt-a001-q.dt.ccp.cable.comcast.com:8095/xconf/swu/stb/";;
        * )
            CLOUD_URL="https://xconf.xcal.tv/xconf/swu/stb/";;   # Pdn server URL
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
    if [ "$1" == "xconf.xcal.tv" ]; then
        request_type=2
    elif [ "$1" == "ci.xconfds.coast.xcal.tv" ]; then
        request_type=4
    else
        request_type=0
    fi
    return $request_type
}

exitForXconf404response () {
    echo "`Timestamp` Received HTTPS 404 Response from Xconf Server. Retry logic not needed"
    echo "`Timestamp` Exiting from Image Upgrade process..!"
    rm -f $FILENAME
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

    #Included additionalFwVerInfo and partnerId
    if [ "$(getModel)" = "RPI" ]; then
      JSONSTR='eStbMac='$(getEstbMacAddress)'&firmwareVersion='$(getFWVersion)'&env='$(getBuildType)'&model='$BOX_MODEL'&localtime='$(getLocalTime)'&timezone='EST05EDT''$CAPABILITIES''
    else
      JSONSTR='eStbMac='$estbMac'&firmwareVersion='$(getFWVersion)'&additionalFwVerInfo='$pdriFwVerInfo''$remoteInfo'&env='$(getBuildType)'&model='$model'&partnerId='$(getPartnerId)'&accountId='$(getAccountId)'&experience='$(getExperience)'&serial='$(getSerialNumber)'&localtime='$(getLocalTime)'&timezone='$zoneValue''$ACTIVATE_FLAG''$CAPABILITIES''
    fi
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
    if [ $curl_result -eq 0 ] && [ "$http_code" = "404" ]; then
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
    if [ "$DisableForcedHttps" != "true" ] ; then
        CLOUD_URL=`echo $CLOUD_URL | sed "s/http:/https:/g"`
    else
        echo "`Timestamp` Ignore forcing to https URL"
    fi
    if [ -f $PERSISTENT_PATH/swupdate.conf ] && [ $BUILD_TYPE != "prod" ] ; then
        CURL_OPTION="-gw"
    fi
    
    sendXCONFRequest 
    ret=$?    

    resp=1
    if [ $ret -ne 0 ] || [ "$http_code" != "200" ] ; then
        echo "`Timestamp` HTTPS request failed"                        
    fi
    return $resp    
} 

### main app

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
    rm -f $FILENAME $HTTP_CODE
    sendJsonRequestToCloud $FILENAME
    cdlRet=$?
    
    if [ $cdlRet != 0 ]; then
        echo "`Timestamp` sendJsonRequestToCloud failed with httpcode: $http_code Ret: $cdlRet"
        sleep 5
        if [ "$http_code" == "404" ];then
            echo "`Timestamp` Giving up all retries as received $http_code response..."
            exit 1
        fi
    else
        echo "`Timestamp` sendJsonRequestToCloud succeeded with httpcode: $http_code Ret: $cdlRet"
    fi

    retryCount=$((retryCount + 1))
done


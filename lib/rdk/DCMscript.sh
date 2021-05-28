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
##################################################################
## Script to do Device Configuration Management
## Updates the following information in the settop box 
##    * Check Schedule
##    * Check Log Upload Settings
##    * Check Configuration
## Author: Ajaykumar/Shakeel/Suraj
##################################################################

. /etc/include.properties
. /etc/device.properties

if [ -f /etc/telemetry2_0.properties ]; then
    . /etc/telemetry2_0.properties
fi

T2_ENABLE=`tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.Telemetry.Enable 2>&1`

# exit if an instance is already running
pid_file="/tmp/.dcm-utility.pid"
if [ -f $pid_file ] && [ -d /proc/`cat $pid_file` ]; then
   exit 0
fi
echo $$ > $pid_file

DCM_SKIP_RETRY_FLAG='/tmp/dcm_not_configured'
WAREHOUSE_ENV="$RAMDISK_PATH/warehouse_mode_active"

# Adding a sleep of 1 minute to avoid the initial 
# CPU load due to ip address check
sleep 90

if [ "$BUILD_TYPE" != "prod" ] && [ -f /opt/dcm.properties ]; then
      . /opt/dcm.properties
else
      . /etc/dcm.properties
fi

if [ "$DEVICE_TYPE" != "mediaclient" ]; then 
   . /lib/rdk/snmpUtils.sh
else
   . /lib/rdk/utils.sh
fi

if [ -z $LOG_PATH ]; then
    LOG_PATH="/opt/logs/"
fi
if [ -z $PERSISTENT_PATH ]; then
    PERSISTENT_PATH="/tmp"
fi
zoneValue=""

export PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/sbin:/usr/local/lighttpd/sbin:/usr/local/sbin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/Qt/lib:/usr/local/lib
TELEMETRY_PATH="/opt/.telemetry"
SORTED_PATTERN_CONF_FILE="$TELEMETRY_PATH/dca_temp_file.conf"
DCMFLAG="/tmp/.DCMSettingsFlag"

#setting TLS value only for Yocto builds
TLS=""
if [ -f /etc/os-release ]; then
    TLS="--tlsv1.2"
fi

TLSRet=""
HTTPS_URL=""
cron_update=0
reboot_flag=$4
if [ $# -ne 5 ]
then
    echo "`/bin/timestamp` Argument does not match" >> $LOG_PATH/dcmscript.log
    echo 0 > $DCMFLAG
    exit 1
fi

. $RDK_PATH/utils.sh

# initialize partnerId
. $RDK_PATH/getPartnerId.sh

echo "`/bin/timestamp` Starting execution of DCMscript.sh" >> $LOG_PATH/dcmscript.log

## Trigger Telemetry run for previous boot log files 
echo "Telemetry run for previous boot log files" >> $LOG_PATH/dcmscript.log
TELEMETRY_PREVIOUS_LOG="/tmp/.telemetry_previous_log"

###########################################################################################
TELEMETRY_PATH_TEMP="$TELEMETRY_PATH/tmp"
T2_SERVICE_PATH="/tmp/enable_t2_service"

SYSTEM_METRIC_CRON_INTERVAL="*/15 * * * *"

t2Log() {
    timestamp=`date +%Y-%b-%d_%H-%M-%S`
    echo "$0 : $timestamp $*" >> $T2_0_LOGFILE
}

systemHealthLog=`sh /lib/rdk/cronjobs_update.sh "check-entry" "vm_cpu_temp-check.sh"`
if [ "$systemHealthLog" != "0" ]; then
    sh /lib/rdk/cronjobs_update.sh "remove" "vm_cpu_temp-check.sh"
fi

sh /lib/rdk/cronjobs_update.sh "update" "vm_cpu_temp-check.sh" "$SYSTEM_METRIC_CRON_INTERVAL nice -n 10 sh $RDK_PATH/vm_cpu_temp-check.sh"

# Check for RFC Telemetry.Enable settings
# Internal syscfg database used by RFC parameter -  Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.Telemetry.Enable

t2Log "RFC value for Telemetry 2.0 Enable is $T2_ENABLE ."
if [ ! -f $T2_0_BIN ]; then
    t2Log "Unable to find $T2_0_BIN ... Switching T2 Enable to false !!!"
    T2_ENABLE="false"
fi

if [ "x$T2_ENABLE" == "xtrue" ]; then
    t2Pid=`pidof $T2_0_APP`
    if [ -z "$t2Pid" ]; then
        echo "${T2_BIN} is present, XCONF config fetch and parse will be handled by T2 implementation" >> $DCM_LOG_FILE
        t2Log "Clearing markers from $TELEMETRY_PATH"
        rm -rf $TELEMETRY_PATH
        mkdir -p $TELEMETRY_PATH
        mkdir -p $TELEMETRY_PATH_TEMP
        touch $T2_SERVICE_PATH
        #${T2_0_BIN}
    else
         mkdir -p $TELEMETRY_PATH_TEMP
         t2Log "telemetry daemon is already running .. Trigger from maintenance window."
         t2Log "Send signal 15 $T2_0_APP to restart for config fetch "
         kill -15 $t2Pid
    fi
    ## Clear any dca_utility.sh cron entries if present from T1.1 previous execution
    dcaCheck=`sh /lib/rdk/cronjobs_update.sh "check-entry" "dca_utility.sh"`
    if [ "$dcaCheck" != "0" ]; then
        sh /lib/rdk/cronjobs_update.sh "remove" "dca_utility.sh"
    fi
    
    exit 0
fi

###########################################################################################

touch $TELEMETRY_PREVIOUS_LOG
# Running previous logs telemetry run in background as previous logs directory will be removed after 7mins sleep in uploadSTBLogs.sh
sh /lib/rdk/dca_utility.sh 0 0 &

# initialize partnerId
. $RDK_PATH/getPartnerId.sh

# initialize accountId
. $RDK_PATH/getAccountId.sh

#---------------------------------
# Initialize Variables
#---------------------------------
# URL
URL=$2
tftp_server=$3
checkon_reboot=$5

#Flag to use Secure endpoints
mTlsLogUpload=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.MTLS.mTlsLogUpload.Enable 2>&1 > /dev/null)
useXpkiMtlsLogupload=false
checkXpkiMtlsBasedLogUpload()
{
    xpkiMtlsRFC=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.UseXPKI.Enable 2>&1 > /dev/null)
    if [ "x$xpkiMtlsRFC" = "xtrue" ] && [ -f /usr/bin/rdkssacli ] && [ -f /opt/certs/devicecert_1.pk12 ]; then
        useXpkiMtlsLogupload="true"
    else
        useXpkiMtlsLogupload="false"
    fi
    echo "`/bin/timestamp` xpki based mtls support = $useXpkiMtlsLogupload" >> $LOG_PATH/dcmscript.log
}
checkXpkiMtlsBasedLogUpload

LOG_CONFIG_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Bootstrap.XconfUrl 2>&1 > /dev/null)

if [ "$LOG_CONFIG_URL" ]; then
    URL="$LOG_CONFIG_URL/loguploader/getSettings"
    echo "`/bin/timestamp` Setting URL to $URL from Bootstrap config LOG_CONFIG_URL:$LOG_CONFIG_URL" >> $LOG_PATH/dcmscript.log
fi

 echo "`/bin/timestamp` URL: $URL" >> $LOG_PATH/dcmscript.log
 echo "`/bin/timestamp` REBOOT_FLAG: $reboot_flag" >> $LOG_PATH/dcmscript.log
 echo "`/bin/timestamp` CHECK_ON_REBOOT: $checkon_reboot" >> $LOG_PATH/dcmscript.log


if [ -f "/tmp/DCMSettings.conf" ]
then
    Check_URL=`grep 'urn:settings:ConfigurationServiceURL' /tmp/DCMSettings.conf | cut -d '=' -f2 | head -n 1`
    if [ -n "$Check_URL" ]
    then
        URL=`grep 'urn:settings:ConfigurationServiceURL' /tmp/DCMSettings.conf | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//' | head -n 1`
        #last_char=`echo $URL | sed -e 's/\(^.*\)\(.$\)/\2/'`
        last_char=`echo $URL | awk '$0=$NF' FS=`
        if [ "$last_char" != "?" ]
        then
            URL="$URL?"
        fi
    fi
fi
# File to save curl response 
FILENAME="$PERSISTENT_PATH/DCMresponse.txt"
# File to save http code
HTTP_CODE="$PERSISTENT_PATH/dcm_curl_httpcode"
rm -rf $HTTP_CODE
# Timeout value
timeout=10
CURL_TLS_TIMEOUT=30
# http header
HTTP_HEADERS='Content-Type: application/json'

## RETRY DELAY in secs
RETRY_DELAY=60
RETRY_DELAY_DCM=300
RETRY_COUNT=3
default_IP=$DEFAULT_IP
upload_protocol='HTTP'

upload_httplink_url=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.SsrUrl 2>&1)
if [ ! -z "$upload_httplink_url" ]; then
    upload_httplink=${upload_httplink_url}/cgi-bin/S3.cgi
else
    . /etc/dcm.properties
    upload_httplink=$HTTP_UPLOAD_LINK
fi

#check if we have bootstrap parameter
bootstrap_upload_httplink=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Bootstrap.SsrUrl 2>&1 > /dev/null)
if [ ! -z "$bootstrap_upload_httplink" ]; then
    echo "Overriding the upload url with bootstrap url" >> $LOG_PATH/dcmscript.log
    upload_httplink="$bootstrap_upload_httplink/cgi-bin/S3.cgi"
fi

MAX_UPLOAD_ATTEMPTS=3
CB_MAX_UPLOAD_ATTEMPTS=1
DIRECT_BLOCK_FILENAME="/tmp/.lastdirectfail_dcm"
CB_BLOCK_FILENAME="/tmp/.lastcodebigfail_dcm"

EnableOCSPStapling="/tmp/.EnableOCSPStapling"
EnableOCSP="/tmp/.EnableOCSPCA"

## Timezone file for all platforms Gram/Fles boxes.
TIMEZONEDST="/opt/persistent/timeZoneDST"

cron=""
sleep_time=0
PREVIOUS_CRON_FILE="/opt/.telemetry_previous_cron_file"
#---------------------------------
# Function declarations
#---------------------------------
IsDirectBlocked()
{
    directret=0
    if [ -f $DIRECT_BLOCK_FILENAME ]; then
        modtime=$(($(date +%s) - $(date +%s -r $DIRECT_BLOCK_FILENAME)))
        remtime=$((($DIRECT_BLOCK_TIME/3600) - ($modtime/3600)))
        if [ "$modtime" -le "$DIRECT_BLOCK_TIME" ]; then
            echo "`/bin/timestamp` DCM: Last direct failed blocking is still valid for $remtime hrs, preventing direct" >> $LOG_PATH/dcmscript.log
            directret=1
        else
            echo "`/bin/timestamp` DCM: Last direct failed blocking has expired, removing $DIRECT_BLOCK_FILENAME, allowing direct" >> $LOG_PATH/dcmscript.log
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
            echo "`/bin/timestamp` DCM: Last Codebig failed blocking is still valid for $cbremtime mins, preventing Codebig" >> $LOG_PATH/dcmscript.log
            codebigret=1
        else
            echo "`/bin/timestamp` DCM: Last Codebig failed blocking has expired, removing $CB_BLOCK_FILENAME, allowing Codebig" >> $LOG_PATH/dcmscript.log
            rm -f $CB_BLOCK_FILENAME
        fi
    fi
    return $codebigret
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

## FW version from version.txt 
getFWVersion()
{
    #cat /version.txt | grep ^imagename:PaceX1 | grep -v image
    verStr=`cat /version.txt | grep ^imagename: | cut -d ":" -f 2`
    echo $verStr
}

## Identifies whether it is a VBN or PROD build
getBuildType()
{
   echo $BUILD_TYPE
}

## Get ECM mac address
getECMMacAddress()
{
    mac=""
    if [ "$DEVICE_TYPE" != "mediaclient" ]; then
        address=`getECMMac`
        mac=`echo $address | tr -d ' ' | tr -d '"'`
    fi
    echo $mac
}

## Get Controller Id
getControllerId()
{
    echo "2504"
}

## Get ChannelMap Id
getChannelMapId()
{
    echo "2345"
}

## Get VOD Id
getVODId()
{
    echo "15660"
}

## Process the responce and update it in a file DCMSettings.conf
processJsonResponse()
{   
    if [ -f "$FILENAME" ]
    then
        OUTFILE='/tmp/DCMSettings.conf'
		OUTFILEOPT='/opt/.DCMSettings.conf'
        sed -i 's/,"urn:/\n"urn:/g' $FILENAME # Updating the file by replacing all ',"urn:' with '\n"urn:'
        sed -i 's/^{//g' $FILENAME # Delete first character from file '{'
        sed -i 's/}$//g' $FILENAME # Delete first character from file '}'
        echo "" >> $FILENAME         # Adding a new line to the file 

        #rm -f $OUTFILE #delete old file
        cat /dev/null > $OUTFILE #empty old file
		cat /dev/null > $OUTFILEOPT

        while read line
        do  
            
            # Parse the settings  by
            # 1) Replace the '":' with '='
            # 2) Updating the result in a output file
            profile_Check=`echo "$line" | grep -ci 'TelemetryProfile'`
            if [ $profile_Check -ne 0 ];then
                #echo "$line"
                echo "$line" | sed 's/"header":"/"header" : "/g' | sed 's/"content":"/"content" : "/g' | sed 's/"type":"/"type" : "/g' >> $OUTFILE
				echo "$line" | sed 's/"header":"/"header" : "/g' | sed 's/"content":"/"content" : "/g' | sed 's/"type":"/"type" : "/g'  | sed -e 's/uploadRepository:URL.*","//g'  >> $OUTFILEOPT
            else
                cron_Check=`echo "$line" | grep 'urn:settings:CheckSchedule:cron' | grep -c '\-1'`
                if [ $cron_Check -ne 0 ];then
                   # correct bad cron rules (-1) from the DCM server
                   echo "Corrected bad cron rule from DCM server: $line" >> $LOG_PATH/dcmscript.log
                   line=`echo "$line" | sed 's/\-1/0/g'`
                fi 
                echo "$line" | sed 's/":/=/g' | sed 's/"//g' >> $OUTFILE 		
            fi            
        done < $FILENAME
        
        rm -rf $FILENAME #Delete the /opt/DCMresponse.txt
    else
        echo "$FILENAME not found." >> $LOG_PATH/dcmscript.log
        return 1
    fi
}

sendTLSDCMCodebigRequest()
{
    CB_SIGNED_REQUEST=$1
    echo "Attempting $TLS connection to Codebig DCM server">> $LOG_PATH/dcmscript.log
    if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
        CURL_CMD="curl $TLS -w '%{http_code}\n' --cert-status --connect-timeout $CURL_TLS_TIMEOUT -m $timeout -o  \"$FILENAME\" \"$CB_SIGNED_REQUEST\""
    else
        CURL_CMD="curl $TLS -w '%{http_code}\n' --connect-timeout $CURL_TLS_TIMEOUT -m $timeout -o  \"$FILENAME\" \"$CB_SIGNED_REQUEST\""
    fi
    echo "`/bin/timestamp` CURL_CMD: $CURL_CMD" >> $LOG_PATH/dcmscript.log
    eval $CURL_CMD > $HTTP_CODE
    TLSRet=$?

    case $TLSRet in
        35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
            echo "HTTPS $TLS failed to connect to Codebig DCM server with curl error code $TLSRet" >> $LOG_PATH/tlsError.log
            ;;
    esac
    echo "Curl return code : $TLSRet" >> $LOG_PATH/dcmscript.log
}

sendTLSDCMRequest()
{
    TLSRet=1
    echo "Attempting $TLS connection to DCM server"  >> $LOG_PATH/dcmscript.log
    if [ "$FORCE_MTLS" == "true" ]; then
        echo "MTLS preferred for DCM Request" >> $LOG_PATH/dcmscript.log
        mTlsLogUpload="true"
    fi

    if [ "$mTlsLogUpload" == "true" ] || [ $useXpkiMtlsLogupload == "true" ]; then
        if [ "$useXpkiMtlsLogupload" == "true" ]; then
            msg_tls_source="mTLS certificate from xPKI"
            echo "Connect with $msg_tls_source"
            CURL_CMD="curl $TLS --cert-type P12 --cert /opt/certs/devicecert_1.pk12:$(/usr/bin/rdkssacli "{STOR=GET,SRC=kquhqtoczcbx,DST=/dev/stdout}") -w '%{http_code}\n' --connect-timeout $CURL_TLS_TIMEOUT -m $timeout -o  \"$FILENAME\" '$HTTPS_URL$JSONSTR'"
        elif [ -f /etc/ssl/certs/staticXpkiCrt.pk12 ]; then
            msg_tls_source="mTLS using static xpki certificate"
            echo "Connect with $msg_tls_source"
            if [ ! -f /usr/bin/GetConfigFile ]; then
                echo "Error: GetConfigFile Not Found"
                exit 127
            fi
            ID="/tmp/.cfgStaticxpki"
            GetConfigFile $ID
            if [ ! -f "$ID" ]; then
                echo "Error: Getconfig file failed"
            fi
            CURL_CMD="curl $TLS --cert-type P12 --cert /etc/ssl/certs/staticXpkiCrt.pk12:$(cat $ID) -w '%{http_code}\n' --connect-timeout $CURL_TLS_TIMEOUT -m $timeout -o  \"$FILENAME\" '$HTTPS_URL$JSONSTR'"
        fi
    else
        msg_tls_source="TLS"
        echo "Connect with $msg_tls_source, no mtls support"
        CURL_CMD="curl $TLS -w '%{http_code}\n' --connect-timeout $CURL_TLS_TIMEOUT -m $timeout -o  \"$FILENAME\" '$HTTPS_URL$JSONSTR'"
    fi
    if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
        CURL_CMD="$CURL_CMD --cert-status"
    fi
    echo "`/bin/timestamp` $msg_tls_source CURL_CMD: `echo "$CURL_CMD" | sed -e 's#devicecert_1.*-w#devicecert_1.pk12<hidden key> -w#g'`" >> $LOG_PATH/dcmscript.log
    eval $CURL_CMD > $HTTP_CODE
    TLSRet=$?

    case $TLSRet in
        35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
            echo "HTTPS with $msg_tls_source for $TLS failed to connect to XCONF server with curl error code $TLSRet" >> $LOG_PATH/tlsError.log
            ;;

    esac
    echo "Curl return code with $msg_tls_source : $TLSRet" >> $LOG_PATH/dcmscript.log
}

DoCodebig()
{
    SIGN_CMD="GetServiceUrl 3 \"$JSONSTR\""
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

    CB_SIGNED_REQUEST=`echo $CB_SIGNED_REQUEST | sed "s/http:/https:/g"`
    sendTLSDCMCodebigRequest $CB_SIGNED_REQUEST
}

sendHttpRequestToServer()
{
    resp=0
    FILENAME=$1
    URL=$2
    #Create json string
    JSONSTR='estbMacAddress='$(getEstbMacAddress)'&firmwareVersion='$(getFWVersion)'&env='$(getBuildType)'&model='$(getModel)'&ecmMacAddress='$(getECMMacAddress)'&controllerId='$(getControllerId)'&channelMapId='$(getChannelMapId)'&vodId='$(getVODId)'&timezone='$zoneValue'&partnerId='$(getPartnerId)'&accountId='$(getAccountId)'&experience='$(getExperience)'&version=2'
    #echo JSONSTR: $JSONSTR

    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/lib:/usr/local/lib

    # Generate curl command
    last_char=`echo $URL | awk '$0=$NF' FS=`
    if [ "$last_char" != "?" ]; then
        URL="$URL?"
    fi
        
    # Force https
    HTTPS_URL=`echo $URL | sed "s/http:/https:/g"`
    http_code="000"
    retries=0
    cbretries=0

    if [ $UseCodebig -eq 1 ]; then
        echo "`/bin/timestamp`:sendHttpRequestToServer: Codebig is enabled UseCodebig:$UseCodebig" >> $LOG_PATH/dcmscript.log
        if [ "$DEVICE_TYPE" = "mediaclient" ]; then
            # Use Codebig connection connection on XI platforms
            IsCodeBigBlocked
            skipcodebig=$?
            if [ $skipcodebig -eq 0 ]; then
                while [ $cbretries -le $CB_MAX_UPLOAD_ATTEMPTS ]
                do
                    echo "`/bin/timestamp`:sendHttpRequestToServer: Attempting Codebig DCM connection" >> $LOG_PATH/dcmscript.log
                    DoCodebig
                    ret=$TLSRet
                    http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                    if [ "$http_code" = "200" ]; then
                        echo "`/bin/timestamp`:sendHttpRequestToServer: Codebig DCM connection success return:$ret, httpcode:$http_code" >> $LOG_PATH/dcmscript.log
                        IsDirectBlocked
                        skipDirect=$?
                        if [ $skipDirect -eq 0 ]; then
                            UseCodebig=0
                        fi
                        break
                    elif [ "$http_code" = "404" ]; then
                       echo "`/bin/timestamp`:sendHttpRequestToServer: Received 404 response for Codebig DCM connection, Retry logic not needed"
                       break
                    fi
                    echo "`/bin/timestamp`:sendHttpRequestToServer: Codebig DCM connection return: retry:$cbretries ret:$ret, httpcode:$http_code" >> $LOG_PATH/dcmscript.log
                    cbretries=`expr $cbretries + 1`
                    sleep 10
                done
            fi

            if [ "$http_code" = "000" ]; then
                echo "`/bin/timestamp`:sendHttpRequestToServer: Codebig DCM connection failed: httpcode:$http_code, attempting direct" >> $LOG_PATH/dcmscript.log
                IsDirectBlocked
                skipdirect=$?
                if [ $skipdirect -eq 0 ]; then
                    # try direct on the last time through
                    UseCodebig=0
                    sendTLSDCMRequest
                    ret=$TLSRet
                    http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                    if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                        echo "`/bin/timestamp`:sendHttpRequestToServer: Direct DCM connection failover attempt failed, return:$ret, httpcode:$http_code" >> $LOG_PATH/dcmscript.log
                    else
                        echo "`/bin/timestamp`:sendHttpRequestToServer: Direct DCM connection failover attempt received, return:$ret, httpcode:$http_code" >> $LOG_PATH/dcmscript.log
                    fi
                fi
                IsCodeBigBlocked
                skipcodebig=$?
                if [ $skipcodebig -eq 0 ]; then
                    echo "`/bin/timestamp`:sendHttpRequestToServer: Codebig blocking is released" >> $LOG_PATH/dcmscript.log
                fi
            elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                echo "`/bin/timestamp`:sendHttpRequestToServer: Codebig DCM Query failed with return=$ret, httpcode:$http_code" >> $LOG_PATH/dcmscript.log
            fi
        else
            echo "`/bin/timestamp`:sendHttpRequestToServer: Codebig DCM connection not supported" >> $LOG_PATH/dcmscript.log
        fi
    else
        echo "`/bin/timestamp`:sendHttpRequestToServer: Codebig is disabled: UseCodebig=$UseCodebig" >> $LOG_PATH/dcmscript.log
        IsDirectBlocked
        skipdirect=$?
        if [ $skipdirect -eq 0 ]; then
            while [ $retries -lt $MAX_UPLOAD_ATTEMPTS ]
            do
                echo "`/bin/timestamp`:sendHttpRequestToServer: Attempting direct DCM connection" >> $LOG_PATH/dcmscript.log
                sendTLSDCMRequest
                ret=$TLSRet
                http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                if [ "$http_code" = "200" ];then
                    echo "`/bin/timestamp`:sendHttpRequestToServer: Direct DCM connection success, return:$ret, httpcode:$http_code" >> $LOG_PATH/dcmscript.log
                    break
                elif [ "$http_code" = "404" ]; then
                    echo "`/bin/timestamp`:sendHttpRequestToServer: Received 404 response for Direct DCM connection, Retry logic not needed"
                    break
                fi
                echo "`/bin/timestamp`:sendHttpRequestToServer: Direct DCM connection retry:$retries, return:$ret, httpcode:$http_code" >> $LOG_PATH/dcmscript.log
                retries=`expr $retries + 1`
                sleep 60
            done
        fi

        if [ "$http_code" = "000" ]; then
            if [ "$DEVICE_TYPE" = "mediaclient"]; then
                echo "`/bin/timestamp`:sendHttpRequestToServer: Direct DCM connection failed: httpcode:$http_code, attempting Codebig" >> $LOG_PATH/dcmscript.log
                IsCodeBigBlocked
                skipcodebig=$?
                if [ $skipcodebig -eq 0 ]; then
                    while [ $cbretries -le $CB_MAX_UPLOAD_ATTEMPTS ]
                    do
                        echo "`/bin/timestamp`:sendHttpRequestToServer: Attempting Codebig DCM connection" >> $LOG_PATH/dcmscript.log
                        DoCodebig 
                        ret=$TLSRet
                        http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                        if [ "$http_code" = "200" ]; then
                            echo "`/bin/timestamp`:sendHttpRequestToServer: Codebig DCM connection success return:$ret, httpcode:$http_code" >> $LOG_PATH/dcmscript.log
                            UseCodebig=1
                            if [ ! -f $DIRECT_BLOCK_FILENAME ]; then
                                touch $DIRECT_BLOCK_FILENAME
                                echo "`/bin/timestamp`:sendHttpRequestToServer: Use Codebig and Block Direct for 24 hrs " >> $LOG_PATH/dcmscript.log
                            fi
                            break
                        elif [ "$http_code" = "404" ]; then
                            echo "`/bin/timestamp`:sendHttpRequestToServer: Received 404 response for Codebig DCM connection, Retry logic not needed"
                            break
                        fi
                        echo "`/bin/timestamp`:sendHttpRequestToServer: Codebig DCM connection return: retry:$cbretries, ret:$ret, httpcode:$http_code" >> $LOG_PATH/dcmscript.log
                        cbretries=`expr $cbretries + 1`
                        sleep 10
                    done

                    if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                        echo "`/bin/timestamp`:sendHttpRequestToServer: Codebig DCM connection failed return=$ret, httpcode:$http_code" >> $LOG_PATH/dcmscript.log
                        UseCodebig=0
                        if [ ! -f $CB_BLOCK_FILENAME ]; then
                            touch $CB_BLOCK_FILENAME
                            echo "`/bin/timestamp`:sendHttpRequestToServer: Switch Direct and Blocking Codebig for 30mins" >> $LOG_PATH/dcmscript.log
                        fi
                    fi
                fi
            else
                echo "`/bin/timestamp`:sendHttpRequestToServer: Codebig DCM connection not supported" >> $LOG_PATH/dcmscript.log
            fi
        elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
            echo "`/bin/timestamp`:sendHttpRequestToServer: Direct DCM connection failed return:$ret, httpcode:$http_code" >> $LOG_PATH/dcmscript.log
        fi
    fi

    if [ $ret = 0 ] && [ "$http_code" = "404" ] ; then
	resp=1
        touch $DCM_SKIP_RETRY_FLAG
    elif [ $ret -ne 0 -o "$http_code" != "200" ] ; then
        echo "`/bin/timestamp` https request failed" >> $LOG_PATH/dcmscript.log
        rm -rf /tmp/DCMSettings.conf
        resp=1
    else
        echo "`/bin/timestamp` https request success. Processing response.." >> $LOG_PATH/dcmscript.log
        # Process the JSON response
        processJsonResponse
        stat=$?
        echo "`/bin/timestamp` processJsonResponse returned $stat" >> $LOG_PATH/dcmscript.log
        if [ "$stat" != 0 ] ; then
            echo "`/bin/timestamp` Processing response failed." >> $LOG_PATH/dcmscript.log
            rm -rf /tmp/DCMSettings.conf
            resp=1
        else
            echo 1 > $DCMFLAG
        fi
    fi
    
    echo "`/bin/timestamp` resp = $resp" >> $LOG_PATH/dcmscript.log
    return $resp
}

echo "`/bin/timestamp` Waiting for IP" >> $LOG_PATH/dcmscript.log
getTimeZone
loop=1
counter=0
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
                   echo "`/bin/timestamp` waiting for IPv6 IP" >> $LOG_PATH/dcmscript.log
                   let counter++
                   if [ "$counter" -eq 30 ] || [ "$counter" -eq 90 ]; then
                       sh $RDK_PATH/dca_utility.sh 0 0
                   fi
               elif [ "Y$estbIp" == "Y$DEFAULT_IP" ] && [ -f /tmp/estb_ipv4 ]; then
                   echo "`/bin/timestamp` waiting for IPv4 IP" >> $LOG_PATH/dcmscript.log
                   let counter++
                   if [ "$counter" -eq 30 ] || [ "$counter" -eq 90 ]; then
                       sh $RDK_PATH/dca_utility.sh 0 0
                   fi
                   sleep 10
               else
                   loop=0
               fi
          else
               if [ "Y$estbIp" == "Y$DEFAULT_IP" ]; then
                   sleep 10
                   let counter++
                   if [ "$counter" -eq 30 ] || [ "$counter" -eq 90 ]; then
                       sh $RDK_PATH/dca_utility.sh 0 0
                   fi
               else
                    loop=0
               fi
          fi
    fi

    # Do not keep spinning too long for RPI models 
    if [ "$BOX_TYPE" == "pi" ] && [ "$counter" -eq 6 ] ; then
        loop=0
    fi

done

#---------------------------------
#        Main App
#---------------------------------
# Enable telemetry profile creation during boot-up

UseCodebig=0

echo "`/bin/timestamp` Check UseCodebig flag" >> $LOG_PATH/dcmscript.log
IsDirectBlocked
UseCodebig=$?

if [ ! $estbIp ] ;then
echo "`/bin/timestamp` Waiting for IP" >> $LOG_PATH/dcmscript.log
fi

loop=1
while [ $loop -eq 1 ]
do
    ret=1
    if [ "$DEVICE_TYPE" != "mediaclient" ] && [ "$estbIp" == "$default_IP" ] ; then
        ret=0
    fi
    while [ $ret -ne 0 ]
    do
        sleep 1
        loop=0
        echo "`/bin/timestamp` --------- box got an ip $estbIp" >> $LOG_PATH/dcmscript.log
        #Checking the value of 'checkon_reboot'
        #The value of 'checkon_reboot' will be 0, if the value of 'urn:settings:CheckOnReboot' is false in DCMSettings.conf
        #The value of 'checkon_reboot' will be always 1, if DCMscript.sh is executing from cronjob
        if [ $checkon_reboot -eq 1 ]; then
            sendHttpRequestToServer $FILENAME $URL
            ret=$?
            echo "`/bin/timestamp` sendHttpRequestToServer returned $ret" >> $LOG_PATH/dcmscript.log
        else
            ret=0
            echo "`/bin/timestamp` sendHttpRequestToServer has not executed since the value of 'checkon_reboot' is $checkon_reboot" >> $LOG_PATH/dcmscript.log
        fi                
        #If sendHttpRequestToServer method fails
        if [ $ret -ne 0 ]
        then
            echo "`/bin/timestamp` Processing response failed." >> $LOG_PATH/dcmscript.log
            count=$((count + 1))
            if [ $count -ge $RETRY_COUNT ]; then
                echo " `/bin/timestamp` $RETRY_COUNT tries failed. Giving up..." >> $LOG_PATH/dcmscript.log
                rm -rf $FILENAME $HTTP_CODE

                if [ -f $PREVIOUS_CRON_FILE ]; then
                    cron=`cat $PREVIOUS_CRON_FILE | grep cron | cut -d ":" -f2`
                    sleep_time=`cat $PREVIOUS_CRON_FILE | grep sleep_time | cut -d ":" -f2`
                fi
                if [ $cron == "" ]; then
                    cron="*/15 * * * *"
                fi
                if [ -z $sleep_time ]; then
                    sleep_time=720
                fi
                sh /lib/rdk/cronjobs_update.sh "update" "dca_utility.sh" "$cron nice -n 19 sh $RDK_PATH/dca_utility.sh $sleep_time 1"

                sh $RDK_PATH/dca_utility.sh 0 1

                if [ "$reboot_flag" == "1" ];then
                    echo "Exiting script." >> $LOG_PATH/dcmscript.log
                    echo 0 > $DCMFLAG
                    exit 0
                fi      
                echo " `/bin/timestamp` Executing $RDK_PATH/uploadSTBLogs.sh." >> $LOG_PATH/dcmscript.log
                nice -n 19 /bin/busybox sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 0 1 $upload_protocol $upload_httplink &
                echo 0 > $DCMFLAG
                exit 1
            fi
            echo "`/bin/timestamp` count = $count. Sleeping $RETRY_DELAY_DCM seconds ..." >> $LOG_PATH/dcmscript.log
            rm -rf $FILENAME $HTTP_CODE
            sleep $RETRY_DELAY_DCM
            if [ "$reboot_flag" == "1" ];then
                echo "Exiting script." >> $LOG_PATH/dcmscript.log
                echo 0 > $DCMFLAG
                exit 0
            fi
        else
            rm -rf $HTTP_CODE
            if [ -f "/tmp/DCMSettings.conf" ]; then
                touch /tmp/.dcm_success
                #---------------------------------------------------------
                upload_protocol=`cat /tmp/DCMSettings.conf | grep 'LogUploadSettings:UploadRepository:uploadProtocol' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
                if [ -n "$upload_protocol" ]; then
                    echo "`/bin/timestamp` upload_protocol: $upload_protocol" >> $LOG_PATH/dcmscript.log
                else
                    upload_protocol='HTTP'
                    echo "`/bin/timestamp` 'urn:settings:LogUploadSettings:Protocol' is not found in DCMSettings.conf" >> $LOG_PATH/dcmscript.log
                fi
                #---------------------------------------------------------
                if [ "$upload_protocol" == "HTTP" ]; then
                    httplink=`cat /tmp/DCMSettings.conf | grep 'LogUploadSettings:UploadRepository:URL' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
                    if [ -z "$httplink" ]; then
                        echo "`/bin/timestamp` 'LogUploadSettings:UploadRepository:URL' is not found in DCMSettings.conf, upload_httplink is '$upload_httplink'" >> $LOG_PATH/dcmscript.log
                    else
                        upload_httplink=$httplink
                        echo "`/bin/timestamp` upload_httplink is $upload_httplink" >> $LOG_PATH/dcmscript.log
                    fi
                    if [ "$FORCE_MTLS" == "true" ]; then
                        echo "MTLS preferred" >> $LOG_PATH/dcmscript.log
                        mTlsLogUpload="true"
                    fi
                    echo "RFC_mTlsLogUpload:$mTlsLogUpload" >> $LOG_PATH/dcmscript.log

                    if [ "$mTlsLogUpload" == "true" ] || [ $useXpkiMtlsLogupload == "true" ]; then
                        #sky endpoint dont use the /secure extension;
                        if [ "$FORCE_MTLS" != "true"  ]; then
                            upload_httplink=`echo $httplink | sed "s|/cgi-bin|/secure&|g"`
                        fi
                    fi
                    echo "`/bin/timestamp` upload_httplink is $upload_httplink" >> $LOG_PATH/dcmscript.log
                fi
                #---------------------------------------------------------
                #Check the value of 'UploadOnReboot' in DCMSettings.conf
                uploadCheck=`cat /tmp/DCMSettings.conf | grep 'urn:settings:LogUploadSettings:UploadOnReboot' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
                cron=`cat /tmp/DCMSettings.conf | grep 'urn:settings:LogUploadSettings:UploadSchedule:cron' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`

                if [ "$uploadCheck" == "true" ] && [ "$reboot_flag" == "0" ]; then
                    # Execute /sysint/uploadSTBLogs.sh with arguments $tftp_server and 1
                    echo "`/bin/timestamp` The value of 'UploadOnReboot' is 'true', executing script uploadSTBLogs.sh" >> $LOG_PATH/dcmscript.log
                    nice -n 19 /bin/busybox sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 1 1 $upload_protocol $upload_httplink &
                elif [ "$uploadCheck" == "false" ] && [ "$reboot_flag" == "0" ]; then
                    # Execute /sysint/uploadSTBLogs.sh with arguments $tftp_server and 1
                    echo "`/bin/timestamp` The value of 'UploadOnReboot' is 'false', executing script uploadSTBLogs.sh" >> $LOG_PATH/dcmscript.log
                    nice  -n 19 /bin/busybox sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 1 0 $upload_protocol $upload_httplink &
                else 
                    echo "Nothing to do here for uploadCheck value = $uploadCheck" >> $LOG_PATH/dcmscript.log
                fi

                #If UploadSchedule:cron is not present in DCMSettings.conf, get the value of urn:settings:LogUploadSettings:UploadSchedule:levelthree:cron
                if [ -z "$cron" ] || [ "$cron" == "null" ]; then
                    echo " `/bin/timestamp` 'UploadSchedule:cron' is not present or null " >> $LOG_PATH/dcmscript.log
                    echo " `/bin/timestamp` Uploading logs as DCM response is either null or not present" >> $LOG_PATH/dcmscript.log
                    rm $LOG_PATH/dcm_upload
                    nice  -n 19 /bin/busybox sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 1 0 $upload_protocol $upload_httplink &
                    echo 0 > $DCMFLAG
                else
                    cron_update=1 
                    echo " `/bin/timestamp` 'UploadSchedule:cron' is present setting cron jobs " >> $LOG_PATH/dcmscript.log
                    sh /lib/rdk/cronjobs_update.sh "update" "uploadSTBLogs.sh" "$cron nice -n 19 /bin/busybox sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 0 1 0 $upload_protocol $upload_httplink"
                fi

                #Get the cornjob value
                #cron=`cat /tmp/DCMSettings.conf | grep 'urn:settings:LogUploadSettings:UploadSchedule:levelone:cron' | cut -d '=' -f2`
                cron=''
                scheduler_Check=`grep '"schedule":' /tmp/DCMSettings.conf`
                if [ -n "$scheduler_Check" ]; then
                    cron=`cat /tmp/DCMSettings.conf | grep -i TelemetryProfile | awk -F '"schedule":' '{print $NF}' | awk -F "," '{print $1}' | sed 's/://g' | sed 's/"//g' | sed -e 's/^[ ]//' | sed -e 's/^[ ]//'`
                fi
                if [ -n "$cron" ]; then
                    cron_update=1 
                    #Get the cronjob time (minutes)
                    sleep_time=`echo "$cron" | awk -F '/' '{print $2}' | cut -d ' ' -f1`
                    if [ -n $sleep_time ]; then
                        sleep_time=`expr $sleep_time - 1` #Subtract 1 miute from it
                        sleep_time=`expr $sleep_time \* 60` #Make it to seconds
                        sleep_time=$(($RANDOM%$sleep_time)) #Generate a random value out of it
                    else
                        sleep_time=10
                    fi
                    sh /lib/rdk/cronjobs_update.sh "update" "dca_utility.sh" "$cron nice -n 19 sh $RDK_PATH/dca_utility.sh $sleep_time 1"
                    echo "cron:$cron" > $PREVIOUS_CRON_FILE
                    echo "sleep_time:$sleep_time" >> $PREVIOUS_CRON_FILE
                else
                    #echo " `/bin/timestamp` Failed to read 'urn:settings:LogUploadSettings:UploadSchedule:levelone:cron' from DCMSettings.conf." >> $LOG_PATH/dcmscript.log
                    echo " `/bin/timestamp` Failed to read \"schedule\" cronjob value from DCMSettings.conf." >> $LOG_PATH/dcmscript.log
                fi

                cron=''
                cron=`cat /tmp/DCMSettings.conf | grep 'urn:settings:CheckSchedule:cron' | cut -d '=' -f2`
                if [ -n "$cron" ]; then
                    cron_update=1 
                    echo "Configuring cron job for deviceInitiatedFWDnld.sh" >> $LOG_PATH/dcmscript.log
                    sh /lib/rdk/cronjobs_update.sh "update" "deviceInitiatedFWDnld.sh" "$cron /bin/sh $RDK_PATH/deviceInitiatedFWDnld.sh 0 2 >> /opt/logs/swupdate.log 2>&1"
		fi	
                        
                if [ $cron_update -eq 1 ]; then
                    . /lib/rdk/ping-telemetry-monitor.sh setcron
                fi

            else
                echo "`/bin/timestamp` /tmp/DCMSettings.conf file not found." >> $LOG_PATH/dcmscript.log
            fi
        fi
    done
    sleep 15
done


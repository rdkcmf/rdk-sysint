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

. /etc/include.properties
. /etc/device.properties

. $RDK_PATH/utils.sh 
. $RDK_PATH/logfiles.sh

# exit if an instance is already running
if [ ! -f /etc/os-release ];then
    if [ ! -f /tmp/.log-upload.pid ];then
        # store the PID
        echo $$ > /tmp/.log-upload.pid
    else
        pid=`cat /tmp/.log-upload.pid`
        if [ -d /proc/$pid ];then
            exit 0
        fi
    fi
fi


if [ "$DEVICE_TYPE" != "mediaclient" ]; then
     . $RDK_PATH/interfaceCalls.sh
     . $RDK_PATH/commonUtils.sh
fi

if [ $# -ne 6 ]; then 
     echo "USAGE: $0 <TFTP Server IP> <Flag (STB delay or not)> <SCP_SERVER> <UploadOnReboot> <UploadProtocol> <UploadHttpLink>"
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

# assign the input arguments
TFTP_SERVER=$1
FLAG=$2
DCM_FLAG=$3
UploadOnReboot=$4
UploadProtocol=$5
UploadHttpLink=$6

# initialize the variables
MAC=`getMacAddressOnly`
HOST_IP=`getIPAddress`
dt=`date "+%m-%d-%y-%I-%M%p"`
LOG_FILE=$MAC"_Logs_$dt.tgz"

#MARKER_FILE=$MAC"_Logs_Marker_$dt.txt"
VERSION="version.txt"
# working folders
PREV_LOG_PATH="$LOG_PATH/PreviousLogs"
PREV_LOG_BACKUP_PATH="$LOG_PATH/PreviousLogs_backup/"
DCM_UPLOAD_LIST="$LOG_PATH/dcm_upload"
TELEMETRY_PATH="/opt/.telemetry"
timeValuePrefix="" 
HTTP_CODE=/tmp/logupload_curl_httpcode
TLS=""
if [ -f /etc/os-release ]; then
    TLS="--tlsv1.2"
fi
CLOUD_URL=""
CURL_TLS_TIMEOUT=30
CURL_TIMEOUT=10
mTlsLogUpload=false
useXpkiMtlsLogupload=false
encryptionEnable=false
if [ -f /etc/os-release ]; then
    encryptionEnable=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.EncryptCloudUpload.Enable 2>&1 > /dev/null`
fi
NUM_UPLOAD_ATTEMPTS=3
CB_NUM_UPLOAD_ATTEMPTS=1
DIRECT_BLOCK_FILENAME="/tmp/.lastdirectfail_upl"
CB_BLOCK_FILENAME="/tmp/.lastcodebigfail_upl"

echo "`/bin/timestamp` Build Type: $BUILD_TYPE Log file: $LOG_FILE UploadProtocol: $UploadProtocol UploadHttpLink: $UploadHttpLink" >> $LOG_PATH/dcmscript.log

upload_flag="true"
if [ -f "/tmp/DCMSettings.conf" ]; then
    upload_flag=`cat /tmp/DCMSettings.conf | grep 'urn:settings:LogUploadSettings:upload' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
    echo "`/bin/timestamp` upload_flag = $upload_flag" >> $LOG_PATH/dcmscript.log
fi

prevUploadFlag=0

EnableOCSPStapling="/tmp/.EnableOCSPStapling"
EnableOCSP="/tmp/.EnableOCSPCA"

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

pidCleanup()
{
     # PID file cleanup
     if [ -f /tmp/.log-upload.pid ];then
          rm -rf /tmp/.log-upload.pid
     fi
}

if [ ! -d $PREV_LOG_PATH ]; then
      echo "The Previous Logs folder is missing" >> $LOG_PATH/dcmscript.log
      if [ ! -f /etc/os-release ];then pidCleanup;fi
      MAINT_LOGUPLOAD_ERROR=5
      eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_ERROR
      exit 0
fi

if [ ! -d "$TELEMETRY_PATH" ]
then
    echo "Telemetry Folder does not exist . Creating now" >> $LOG_PATH/dcmscript.log
    mkdir -p "$TELEMETRY_PATH"
fi

if [ ! -d $DCM_LOG_PATH ]; then                              
    echo "DCM log Folder does not exist . Creating now" >> $LOG_PATH/dcmscript.log
    mkdir -p "$DCM_LOG_PATH" 
fi  

IsDirectBlocked()
{
    directret=0
    if [ -f $DIRECT_BLOCK_FILENAME ]; then
        modtime=$(($(date +%s) - $(date +%s -r $DIRECT_BLOCK_FILENAME)))
        remtime=$((($DIRECT_BLOCK_TIME/3600) - ($modtime/3600)))
        if [ "$modtime" -le "$DIRECT_BLOCK_TIME" ]; then
            echo "`/bin/timestamp`uploadSTBLogs: Last direct failed blocking is still valid for $remtime hrs, preventing direct" >> $LOG_PATH/dcmscript.log
            directret=1
        else
            echo "`/bin/timestamp`uploadSTBLogs: Last direct failed blocking has expired, removing $DIRECT_BLOCK_FILENAME, allowing direct" >> $LOG_PATH/dcmscript.log
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
            echo "`/bin/timestamp`uploadSTBLogs: Last Codebig failed blocking is still valid for $cbremtime mins, preventing Codebig" >> $LOG_PATH/dcmscript.log
            codebigret=1
        else
            echo "`/bin/timestamp`uploadSTBLogs: Last Codebig failed blocking has expired, removing $CB_BLOCK_FILENAME, allowing Codebig" >> $LOG_PATH/dcmscript.log
            rm -f $CB_BLOCK_FILENAME
        fi
    fi
    return $codebigret
}

getFWVersion()
{
    verStr=`cat /version.txt | grep ^imagename: | cut -d ":" -f 2`
    echo $verStr
}

backupAppLogs()                                                        
{                                                               
    source=$1                                                   
    destn=$2                                                    
    if [ -f $source$RILog ] ; then cp $source$RILog $destn; fi  
    if [ -f $source$XRELog ] ; then cp $source$XRELog $destn; fi
    if [ -f $source$WBLog ] ; then cp $source$WBLog $destn; fi  
    if [ -f $source$SysLog ] ; then cp $source$SysLog $destn; fi
}  
renameRotatedLogs()
{
    logPath=$1
    if [ -f $RDK_PATH/renameRotatedLogs.sh ]; then
         if [ -f $logPath/ocapri_log.txt ] ; then sh $RDK_PATH/renameRotatedLogs.sh $logPath/ocapri_log.txt; fi
         if [ -f $logPath/receiver.log ] ; then sh $RDK_PATH/renameRotatedLogs.sh $logPath/receiver.log; fi
         if [ -f $logPath/greenpeak.log ] ; then sh $RDK_PATH/renameRotatedLogs.sh $logPath/greenpeak.log; fi
         if [ -f $logPath/gp_init.log ] ; then sh $RDK_PATH/renameRotatedLogs.sh $logPath/gp_init.log; fi
         if [ -f $logPath/app_status.log ] ; then sh $RDK_PATH/renameRotatedLogs.sh $logPath/app_status.log; fi
    fi
}
processLogsFolder()
{
    srcLogPath=$1
    destnLogPath=$2
    backupAppLogs "$srcLogPath/" "$destnLogPath/"
    backupSystemLogFiles "cp" $srcLogPath $destnLogPath
    backupAppBackupLogFiles "cp" $srcLogPath $destnLogPath

    if [ -f $RAMDISK_PATH/disk_log.txt ]; then cp $RAMDISK_PATH/disk_log.txt $destnLogPath ; fi

    backupCount=`ls $srcLogPath/logbackup-* 2>/dev/null | wc -l`
    if [ $backupCount -gt 0 ]; then
       cp -r $srcLogPath/logbackup-* $destnLogPath
    fi

    if [ -f $srcLogPath/$rebootLog ]; then cp $srcLogPath/$rebootLog $destnLogPath; fi
    if [ -f $srcLogPath/$ablReasonLog ]; then cp $srcLogPath/$ablReasonLog $destnLogPath; fi
    if [ -f $srcLogPath/$ueiLog ]; then cp $srcLogPath/$ueiLog $destnLogPath; fi
    if [ -f $PERSISTENT_PATH/sventest/p3541_all_csven_AV_health_data_trigger.tar.gz ] ; then
        cp $PERSISTENT_PATH/sventest/p3541_all_csven_AV_health_data_trigger.tar.gz $destnLogPath
    fi
    if [ "$DEVICE_TYPE" != "mediaclient" ]; then
          renameRotatedLogs $srcLogPath
    fi
}
modifyFileWithTimestamp()
{
    srcLogPath=$1
    ret=`ls $srcLogPath/*.txt | wc -l`
    if [ ! $ret ]; then 
         ret=`ls $srcLogPath/*.log | wc -l`
         if [ ! $ret ]; then 
              if [ ! -f /etc/os-release ];then pidCleanup;fi
              MAINT_LOGUPLOAD_ERROR=5
              eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_ERROR
              exit 1
         fi
    fi

    dt=`date "+%m-%d-%y-%I-%M%p-"`
    FILES=*.*
    FILES1=".*-[0-9][0-9]AM-.*"
    FILES2=".*-[0-9][0-9]PM-.*"

    for f in $FILES
    do
        test1=0
        test2=0
        test3=0
        test4=0

        test1=`expr match $f $FILES1`
        test2=`expr match $f $FILES2`
        test3=`expr match $f $rebootLog`
        test4=`expr match $f $ablReasonLog`

        if [ $test1 -gt 0 -o $test2 -gt 0 -o $test3 -gt 0 -o $test4 -gt 0 ];  then
            echo "`/bin/timestamp` Processing file...$f"  >> $LOG_PATH/dcmscript.log
        else
            mv $f $dt$f
        fi
    done
    timeValuePrefix="$dt"  
    #cp /version.txt ./$dt$VERSION
}

modifyTimestampPrefixWithOriginalName()
{
    srcLogPath=$1
    ret=`ls $srcLogPath/*.txt | wc -l`
    if [ ! $ret ]; then
         ret=`ls $srcLogPath/*.log | wc -l`
         if [ ! $ret ]; then
              if [ ! -f /etc/os-release ];then pidCleanup;fi
              MAINT_LOGUPLOAD_ERROR=5
              eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_ERROR
              exit 1
         fi
    fi
    FILES=*.*
    cd $srcLogPath
    len=`echo ${#timeValuePrefix}` 
    len=`expr $len + 1`
    for f in $FILES
    do
        originalName=`echo $f| cut -c$len-`
        mv $f $originalName
    done
    cd -
}

copyAllFiles ()
{

     EXCLUDE="dcm PreviousLogs_backup PreviousLogs"
     cd $LOG_PATH
     for fileName in *
     do
        COPY_BOOLEAN=true
        for excl in $EXCLUDE
        do  
            if [ $excl == $fileName ]; then
              COPY_BOOLEAN=false
            fi  
        done
        if $COPY_BOOLEAN; then	
           cp -R $fileName $DCM_LOG_PATH
        fi
     done
}
copyOptLogsFiles ()
{
   cd $LOG_PATH
   cp  * $DCM_LOG_PATH >> $LOG_PATH/dcmscript.log  2>&1
}

logTLSError ()
{
    TLSRet=$1
    server=$2
    case $TLSRet in
        35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
            echo "HTTPS $TLS failed to connect to $server server with curl error code $TLSRet" >> $LOG_PATH/tlsError.log
            ;;
    esac
}

sendTLSSSRCodebigRequest()
{
    POST_URL=$1
    URLENCODE_STRING=""
    if [ "$S3_MD5SUM" != "" ]; then
        URLENCODE_STRING="--data-urlencode \"md5=$S3_MD5SUM\""
    fi

    echo "Attempting $TLS connection to Codebig SSR server"  >> $LOG_PATH/dcmscript.log
    if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
        CURL_CMD="curl $TLS -w '%{http_code}\n' -d \"filename=$2\" $URLENCODE_STRING -o \"$FILENAME\" -H '$authorizationHeader'  \"$POST_URL\" --cert-status --connect-timeout $CURL_TLS_TIMEOUT -m 10"
    else
        CURL_CMD="curl $TLS -w '%{http_code}\n' -d \"filename=$2\" $URLENCODE_STRING -o \"$FILENAME\" -H '$authorizationHeader'  \"$POST_URL\" --connect-timeout $CURL_TLS_TIMEOUT -m 10"
    fi
    echo "URL_CMD: $CURL_CMD" >> $LOG_PATH/dcmscript.log
    eval $CURL_CMD > $HTTP_CODE
    TLSRet=$?

    logTLSError $TLSRet "Codebig SSR"
    echo "Curl return code : $TLSRet" >> $LOG_PATH/dcmscript.log
}

sendTLSSSRRequest()
{
    TLSRet=1
    URLENCODE_STRING=""
    echo "RFC_EncryptCloudUpload_Enable:$encryptionEnable" >> $LOG_PATH/dcmscript.log
    if [ "$S3_MD5SUM" != "" ]; then
        URLENCODE_STRING="--data-urlencode \"md5=$S3_MD5SUM\""
    fi

    echo "Attempting $TLS connection to SSR server"  >> $LOG_PATH/dcmscript.log
    checkXpkiMtlsBasedLogUpload
    mTlsLogUpload=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.MTLS.mTlsLogUpload.Enable 2>&1 > /dev/null`

    if [ "$FORCE_MTLS" == "true" ]; then
        echo "$timestamp: MTLS prefered, force mTlsLogUpload to true"
        mTlsLogUpload=true
    fi

    if [ "$mTlsLogUpload" == "true" ] || [ $useXpkiMtlsLogupload == "true" ]; then
        echo "Log Upload requires Mutual Authentication" >> $LOG_PATH/dcmscript.log
        if [ "$useXpkiMtlsLogupload" == "true" ]; then
            msg_tls_source="mTLS certificate from xPKI"
            echo "Connect with $msg_tls_source"
            CURL_CMD="curl --cert-type P12 --cert /opt/certs/devicecert_1.pk12:$(/usr/bin/rdkssacli "{STOR=GET,SRC=kquhqtoczcbx,DST=/dev/stdout}") -w '%{http_code}\n' -d \"filename=$1\" $URLENCODE_STRING -o \"$FILENAME\" \"$CLOUD_URL\" --connect-timeout $CURL_TLS_TIMEOUT -m 10"
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
            CURL_CMD="curl --cert-type P12 --cert /etc/ssl/certs/staticXpkiCrt.pk12:$(cat $ID) -w '%{http_code}\n' -d \"filename=$1\" $URLENCODE_STRING -o \"$FILENAME\" \"$CLOUD_URL\" --connect-timeout $CURL_TLS_TIMEOUT -m 10"
        fi
    else
        msg_tls_source="TLS"
        echo "Connect with $msg_tls_source, no mtls support"
        CURL_CMD="curl $TLS -w '%{http_code}\n' -d \"filename=$1\" $URLENCODE_STRING -o \"$FILENAME\" \"$CLOUD_URL\" --connect-timeout $CURL_TLS_TIMEOUT -m 10"
    fi

    if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
        CURL_CMD="$CURL_CMD --cert-status"
    fi
    echo "Log Upload: Connect with $msg_tls_source URL_CMD: `echo "$CURL_CMD" | sed -e 's#devicecert_1.*-w#devicecert_1.pk12<hidden key> -w#g'`" >> $LOG_PATH/dcmscript.log
    eval $CURL_CMD > $HTTP_CODE
    TLSRet=$?

    logTLSError $TLSRet "SSR"
    echo "Log Upload: Connect with $msg_tls_source Curl return code : $TLSRet" >> $LOG_PATH/dcmscript.log
}

DoCodebigSSR()
{
    SIGN_CMD="GetServiceUrl 1 \"$UploadHttpParams?filename=$1$uploadfile_md5\""
    eval $SIGN_CMD > /tmp/.signedRequest
    CB_CLOUD_URL=`cat /tmp/.signedRequest`
    rm -f /tmp/.signedRequest

    authorizationHeader=`echo $CB_CLOUD_URL | sed -e "s|&|\", |g" -e "s|=|=\"|g" -e "s|.*filename|filename|g"`
    authorizationHeader="Authorization: OAuth realm=\"\", $authorizationHeader\""
    POST_URL=`echo $CB_CLOUD_URL | sed -e "s|?.*||g"`

    sendTLSSSRCodebigRequest $POST_URL $1
}

HttpLogUpload()
{
    result=1
    FILENAME='/tmp/httpresult.txt'
    CLOUD_URL=`echo $UploadHttpLink | sed "s/http:/https:/g"`
    domainName=`echo $CLOUD_URL | awk -F/ '{print $3}'`
    UploadHttpParams=`echo $CLOUD_URL | sed -e "s|.*$domainName||g"`
    http_code="000"
    retries=0
    cbretries=0

    S3_MD5SUM=""
    echo "RFC_EncryptCloudUpload_Enable:$encryptionEnable" >> $LOG_PATH/dcmscript.log
    if [ "$encryptionEnable" == "true" ]; then
        S3_MD5SUM="$(openssl md5 -binary < $1 | openssl enc -base64)"
        uploadfile_md5="&md5=$S3_MD5SUM"
    fi
            
    if [ $UseCodebig -eq 1 ]; then
        echo "`/bin/timestamp`HttpLogUpload: Codebig is enabled UseCodebig=$UseCodebig" >> $LOG_PATH/dcmscript.log
        if [ "$DEVICE_TYPE" = "mediaclient" ]; then
            # Use Codebig connection connection on XI platforms
            IsCodeBigBlocked
            skipcodebig=$?
            if [ $skipcodebig -eq 0 ]; then
                while [ "$cbretries" -le $CB_NUM_UPLOAD_ATTEMPTS ]
                do        
                    echo "`/bin/timestamp`HttpLogUpload: Attempting Codebig log upload" >> $LOG_PATH/dcmscript.log
                    DoCodebigSSR $1
                    http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                    if [ "$http_code" = "200" ]; then      # anything other than success causes retries
                        echo "`/bin/timestamp`HttpLogUpload: Codebig log upload Success: ret=$ret httpcode=$http_code" >> $LOG_PATH/dcmscript.log
                        IsDirectBlocked
                        skipDirect=$?
                        if [ $skipDirect -eq 0 ]; then
                            UseCodebig=0
                        fi
                        break
                    elif [ "$http_code" = "404" ]; then
                        echo "`/bin/timestamp`HttpLogUpload: Received 404 response for Codebig log upload, Retry logic not needed" >> $LOG_PATH/dcmscript.log
                        break
                    fi
                    echo "`/bin/timestamp`HttpLogUpload: Codebig log upload return: retry=$cbretries, httpcode=$http_code" >> $LOG_PATH/dcmscript.log
                    cbretries=`expr $cbretries + 1`
                    sleep 10
                done
            fi

            if [ "$http_code" = "000" ];then
                IsDirectBlocked
                skipdirect=$?
                if [ $skipdirect -eq 0 ]; then
                    UseCodebig=0
                    echo "`/bin/timestamp`HttpLogUpload: Codebig log upload failed: httpcode=$http_code, attempting direct " >> $LOG_PATH/dcmscript.log
                    sendTLSSSRRequest $1
                    ret=$TLSRet
                    http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                    if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                        echo "`/bin/timestamp`HttpLogUpload: Direct log attempt failover failed return=$ret, httpcode=$http_code" >> $LOG_PATH/dcmscript.log
                    else
                        echo "`/bin/timestamp`HttpLogUpload: Direct log attempt failover received return=$ret, httpcode=$http_code" >> $LOG_PATH/dcmscript.log
                    fi
                fi
                IsCodeBigBlocked
                skipcodebig=$?
                if [ $skipcodebig -eq 0 ]; then
                    echo "`/bin/timestamp`HttpLogUpload: Codebig block released" >> $LOG_PATH/dcmscript.log
                fi
            elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                echo "`/bin/timestamp`HttpLogUpload: Codebig log upload failed with httpcode=$http_code" >> $LOG_PATH/dcmscript.log
            fi
        else
            echo "`/bin/timestamp`HttpLogUpload: Codebig log upload is not supported" >> $LOG_PATH/dcmscript.log
        fi
    else
        echo "`/bin/timestamp`HttpLogUpload: Codebig is disabled UseCodebig=$UseCodebig" >> $LOG_PATH/dcmscript.log
        IsDirectBlocked
        skipdirect=$? 
        if [ $skipdirect -eq 0 ]; then
            while [ "$retries" -lt $NUM_UPLOAD_ATTEMPTS ]
            do
                echo "`/bin/timestamp`HttpLogUpload: Attempting direct log upload" >> $LOG_PATH/dcmscript.log
                sendTLSSSRRequest $1
                ret=$TLSRet
                http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                if [ "$http_code" = "200" ];then       # anything other than success causes retries
                    echo "`/bin/timestamp`HttpLogUpload: Direct log upload Success: httpcode=$http_code" >> $LOG_PATH/dcmscript.log
                    break
                elif [ "$http_code" = "404" ]; then
                    echo "`/bin/timestamp`HttpLogUpload: Received 404 response for Direct log upload, Retry logic not needed" >> $LOG_PATH/dcmscript.log
                    break
                fi
                retries=`expr $retries + 1`
                echo "`/bin/timestamp`HttpLogUpload: Direct log upload attempt return: retry=$retries, httpcode=$http_code" >> $LOG_PATH/dcmscript.log
                sleep 60
            done
        fi 
    
        if [ "$http_code" = "000" ]; then
            if [ "$DEVICE_TYPE" = "mediaclient" ]; then      # only fallback if server doesn't respond
                IsCodeBigBlocked 
                skipcodebig=$?
                if [ $skipcodebig -eq 0 ]; then
                    while [ "$cbretries" -le $CB_NUM_UPLOAD_ATTEMPTS ]
                    do 
                        echo "`/bin/timestamp`HttpLogUpload: Direct log upload failed: httpcode=$http_code, attempting Codebig" >> $LOG_PATH/dcmscript.log     
                        DoCodebigSSR $1
                        http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                        if [ "$http_code" = "200" ]; then
                            echo "`/bin/timestamp`HttpLogUpload: CodeBig log upload Success: httpcode=$http_code " >> $LOG_PATH/dcmscript.log                      
                            UseCodebig=1
                            if [ ! -f $DIRECT_BLOCK_FILENAME ]; then
                                echo "`/bin/timestamp`HttpLogUpload: Use CodeBig and Blocking Direct attempts for 24hrs" >> $LOG_PATH/dcmscript.log
                                touch $DIRECT_BLOCK_FILENAME
                            fi
                            break
                        elif [ "$http_code" = "404" ]; then
                            echo "`/bin/timestamp`HttpLogUpload: Received 404 response for Codebig log upload, Retry logic not needed" >> $LOG_PATH/dcmscript.log
                            break
                        fi
                        echo "`/bin/timestamp`HttpLogUpload: Codebig failover attempt return retry=$cbretries, httpcode=$http_code" >> $LOG_PATH/dcmscript.log
                        cbretries=`expr $cbretries + 1`
                        sleep 10
                    done

                    if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                        echo "`/bin/timestamp`HttpLogUpload: Codebig log upload Failed: httpcode=$http_code" >> $LOG_PATH/dcmscript.log
                        UseCodebig=0
                        if [ ! -f $CB_BLOCK_FILENAME ]; then
                            echo "`/bin/timestamp`HttpLogUpload: Switch Direct and Blocking Codebig for 30mins," >> $LOG_PATH/dcmscript.log
                            touch $CB_BLOCK_FILENAME
                        fi
                    fi
                fi
            else
                echo "`/bin/timestamp`HttpLogUpload: Codebig log upload is not supported" >> $LOG_PATH/dcmscript.log
            fi
        elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
            echo "`/bin/timestamp`HttpLogUpload: Direct log upload failed: httpcode=$http_code" >> $LOG_PATH/dcmscript.log
        fi
    fi

    if [ "$http_code" = "200" ];then
        echo "`/bin/timestamp` S3 upload query success. Got new S3 url to upload log" >> $LOG_PATH/dcmscript.log
        #Get the url from FILENAME
        if [ "$encryptionEnable" == "true" ]; then
            NewUrl=$(cat $FILENAME)
        else
            NewUrl=\"$(awk -F\" '{print $1}' $FILENAME)\"
        fi

        NewUrl=`echo $NewUrl | sed "s/http:/https:/g"`
        echo "`/bin/timestamp` Attempting $TLS connection for Uploading Logs to S3 Amazon server" >> $LOG_PATH/dcmscript.log
        if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
            CURL_CMD="curl $TLS -w '%{http_code}\n' -T \"$1\" -o \"$FILENAME\" $NewUrl --cert-status --connect-timeout 60 -m 120 -v"
        else
            CURL_CMD="curl $TLS -w '%{http_code}\n' -T \"$1\" -o \"$FILENAME\" $NewUrl --connect-timeout 60 -m 120 -v"
        fi
        # RDK-20447 --- https://ccp.sys.comcast.net/browse/RDK-20447
        #Modified the NewUrl value to remove the signature parameter & its value from loggging in to a decmscript.log file
        RemSignature=`echo $NewUrl | sed "s/AWSAccessKeyId=.*Signature=.*&//g;s/.*https/https/g"`
        if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
            LogCurlCmd="curl $TLS -w '%{http_code}\n' -T \"$1\" -o \"$FILENAME\" \"$RemSignature\" --cert-status --connect-timeout 60 -m 120 -v"
        else
            LogCurlCmd="curl $TLS -w '%{http_code}\n' -T \"$1\" -o \"$FILENAME\" \"$RemSignature\" --connect-timeout 60 -m 120 -v"
        fi
        echo "URL_CMD: $LogCurlCmd" >> $LOG_PATH/dcmscript.log
        #RDK-20447 --End

        eval $CURL_CMD > $HTTP_CODE
        ret=$?
        logTLSError $ret "S3"
        http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
        rm $FILENAME 
        # Curl ret and http_code
        echo "`/bin/timestamp` ret = $ret http_code: $http_code" >> $LOG_PATH/dcmscript.log
    
        if [ "$http_code" = "200" ];then
            result=0
        else
   
            if [ "$DEVICE_TYPE" == "mediaclient" ]; then
                if [ "$encryptionEnable" == "true" ]; then
                    PROXY_BUCKET=`echo $PROXY_BUCKET | sed "s|unenc||g"`
                fi
                echo "`/bin/timestamp` Trying logupload through Proxy server" >> $LOG_PATH/dcmscript.log
                S3_Bucket=`echo $CURL_CMD | sed "s|.*https://||g" | cut -d "/" -f1`

                CURL_CMD=`echo $CURL_CMD | sed "s|$S3_Bucket|$PROXY_BUCKET|g" | sed 's|?.*"|"|g'`
                LogCurlCmd=`echo $LogCurlCmd | sed "s|$S3_Bucket|$PROXY_BUCKET|g" | sed 's|?.*"|"|g'`
                echo "URL_CMD: $LogCurlCmd" >> $LOG_PATH/dcmscript.log

                eval $CURL_CMD > $HTTP_CODE
                ret=$?
                http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
                rm $FILENAME
                # Curl ret and http_code
                echo "`/bin/timestamp` ret = $ret http_code: $http_code" >> $LOG_PATH/dcmscript.log

            fi        
            if [ "$http_code" = "200" ];then
                echo "`/bin/timestamp` LogUpload is successful" >> $LOG_PATH/dcmscript.log
                result=0
            else
                echo "`/bin/timestamp` Failed Uploading Logs through - HTTP" >> $LOG_PATH/dcmscript.log
            fi
        fi
    else
        echo "`/bin/timestamp` S3 upload query Failed" >> $LOG_PATH/dcmscript.log
    fi
   echo $result
}

UseCodebig=0

echo "`/bin/timestamp` Check Codebig flag,,," >> $LOG_PATH/dcmscript.log
IsDirectBlocked
UseCodebig=$?

# Retain only the last packet capture
clearOlderPacketCaptures()
{
    #Remove *.pcap files from /opt/logs
    pcapCount=`ls $LOG_PATH/*.pcap* | wc -l`
    ## Retain last packet capture
    if [ $pcapCount -gt 0 ]; then
        lastEasPcapCapture="$LOG_PATH/eas.pcap"
        lastMocaPcapCapture="$LOG_PATH/moca.pcap"
        ## Back up last packet capture
        if [ -f $lastEasPcapCapture ]; then
            mv $lastEasPcapCapture $lastEasPcapCapture.bkp
        fi
        if [ -f $lastMocaPcapCapture ]; then
            mv $lastMocaPcapCapture $lastMocaPcapCapture.bkp
        fi
        rm -f $LOG_PATH/*.pcap
        if [ -f $lastEasPcapCapture.bkp ]; then
            mv $lastEasPcapCapture.bkp $lastEasPcapCapture
        fi
        if [ -f $lastMocaPcapCapture.bkp ]; then
            mv $lastMocaPcapCapture.bkp $lastMocaPcapCapture
        fi
    fi
    
    rm -f $LOG_PATH/eas.pcap.*
}

uploadDCMLogs()
{
   cd $DCM_LOG_PATH
   
   if [ "$upload_flag" == "true" ]; then
       echo "`/bin/timestamp` Uploading Logs through DCM cron job" >> $LOG_PATH/dcmscript.log
       modifyFileWithTimestamp $DCM_LOG_PATH >> $LOG_PATH/dcmscript.log  2>&1
       # Include latest moca-capture in uploaded logs for mediaclient device 
       if [ "$DEVICE_TYPE" == "mediaclient" ]; then
           pcapCount=`ls $LOG_PATH/*-moca.pcap | wc -l`
           if [ $pcapCount -gt 0 ]; then
               lastPcapCapture=`ls -lst $LOG_PATH/*.pcap | head -n 1`
               lastPcapCapture=`echo ${lastPcapCapture##* }`
               cp $lastPcapCapture .
           fi
       fi
       tar -zcvf $LOG_FILE * >> $LOG_PATH/dcmscript.log  2>&1
       sleep 60
       echo "`/bin/timestamp` Uploading logs $LOG_FILE  onto $TFTP_SERVER" >> $LOG_PATH/dcmscript.log   
       
       retval=1

        if [ "$UploadProtocol" == "HTTP" ];then
            retval=$(HttpLogUpload $LOG_FILE)
            if [ $retval -eq 0 ];then
                maintenance_error_flag=0
                echo "`/bin/timestamp` Done Uploading Logs through HTTP" >> $LOG_PATH/dcmscript.log
            else
                maintenance_error_flag=1 
            fi
           
        else
            echo "UploadProtocol is not HTTP" >> $LOG_PATH/dcmscript.log
        fi
        clearOlderPacketCaptures
   fi
    
     if [ -d $DCM_LOG_PATH ]; then
          rm -rf $DCM_LOG_PATH/
     fi
}

uploadLogOnReboot()
{
    uploadLog=$1
    ret=`ls $PREV_LOG_PATH/*.txt | wc -l`
    if [ ! $ret ]; then 
         ret=`ls $PREV_LOG_PATH/*.log | wc -l` 
         if [ ! $ret ]; then 
               if [ ! -f /etc/os-release ];then pidCleanup;fi
               MAINT_LOGUPLOAD_ERROR=5
               eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_ERROR 
               exit 1
         fi
    fi
    echo "`/bin/timestamp` Sleeping for seven minutes " >> $LOG_PATH/dcmscript.log
    sleep 330
    echo "`/bin/timestamp` Done sleeping" >> $LOG_PATH/dcmscript.log
    # Special processing - Permanently backup logs on box delete the logs older than 
    # 3 days to take care of old filename
    stat=`find /opt/logs -name "*-*-*-*-*M-" -mtime +3 -exec rm -rf {} \;`
    # for the new filenames with suffix logbackup
    stat=`find /opt/logs -name "*-*-*-*-*M-logbackup" -mtime +3 -exec rm -rf {} \;`
    TIMESTAMP=`date "+%m-%d-%y-%I-%M%p-logbackup"`                   
    PERM_LOG_PATH="$LOG_PATH/$TIMESTAMP"                                
    mkdir -p $PERM_LOG_PATH                                             
    echo $PERM_LOG_PATH >> $TELEMETRY_PATH/lastlog_path
    #processLogsFolder $PREV_LOG_PATH $PERM_LOG_PATH
    cd $PREV_LOG_PATH
    rm $LOG_FILE
    modifyFileWithTimestamp $PREV_LOG_PATH >> $LOG_PATH/dcmscript.log  2>&1

    if $uploadLog; then
        if [ "$DEVICE_TYPE" == "mediaclient" ]; then
           pcapCount=`ls $LOG_PATH/*-moca.pcap | wc -l`
           if [ $pcapCount -gt 0 ]; then
               lastPcapCapture=`ls -lst $LOG_PATH/*.pcap | head -n 1`
               lastPcapCapture=`echo ${lastPcapCapture##* }`
               cp $lastPcapCapture .
           fi
        fi
        tar -zcvf $LOG_FILE * >> $LOG_PATH/dcmscript.log  2>&1
        sleep 60
        if [ "$UploadProtocol" == "HTTP" ];then
            retval=$(HttpLogUpload $LOG_FILE)
            if [ $retval -ne 0 ];then
                echo "`/bin/timestamp`  HTTP log upload failed" >> $LOG_PATH/dcmscript.log
                maintenance_error_flag=1
            else
                maintenance_error_flag=0
            fi
        fi
        clearOlderPacketCaptures
    fi
    cd $PREV_LOG_PATH
    sleep 5    
    if [ -f $PREV_LOG_PATH/$LOG_FILE ]; then 
         rm -rf $PREV_LOG_PATH/$LOG_FILE
    fi
    modifyTimestampPrefixWithOriginalName $PREV_LOG_PATH
    mv $PREV_LOG_PATH/* $PERM_LOG_PATH
    if [ -d $PREV_LOG_BACKUP_PATH ]; then
         rm -rf  $PREV_LOG_BACKUP_PATH
    fi
    mkdir -p $PREV_LOG_BACKUP_PATH
    echo "`/bin/timestamp` Deleting from Previous Logs  Folder " >> $LOG_PATH/dcmscript.log
    if [ -d $PREV_LOG_PATH ]; then
       rm -rf $PREV_LOG_PATH/*
    fi
}

if [ -d $DCM_LOG_PATH ]; then
     rm -rf $DCM_LOG_PATH/
fi
#Remove *.tgz files from /opt/logs
stat=`find $LOG_PATH -name "*.tgz" -exec rm -rf {} \;`
clearOlderPacketCaptures

#Remove files which have timestamp in it filename
for item in `ls $LOG_PATH/*-*-*-*-*M-* | grep "[0-9]*-[0-9]*-[0-9]*-[0-9]*-M*" | grep -v "logbackup" | grep -v "moca.pcap"`;do
    if [ -f "$item" ];then
        echo "`/bin/timestamp` Removing $item" >> $LOG_PATH/dcmscript.log
        rm -rf $item
    fi
done

if [ $DCM_FLAG -eq 0 ] ; then 
     echo "`/bin/timestamp`  Uploading Without DCM" >> $LOG_PATH/dcmscript.log
     uploadLogOnReboot true
else 
     if [ $FLAG -eq 1 ] ; then 
       if [ $UploadOnReboot -eq 1 ]; then	
           echo "`/bin/timestamp` Uploading Logs with DCM UploadOnReboot set to true" >> $LOG_PATH/dcmscript.log
           uploadLogOnReboot true	
        else 
           echo "`/bin/timestamp` Not Uploading Logs with DCM UploadOnReboot set to false" >> $LOG_PATH/dcmscript.log
           maintenance_error_flag=1
           uploadLogOnReboot false
           echo $PERM_LOG_PATH >> $DCM_UPLOAD_LIST
       fi
     else
       if [ $UploadOnReboot -eq 0 ]; then  
          mkdir -p $DCM_LOG_PATH
          fileUploadCount=`cat "$DCM_UPLOAD_LIST" | wc -l`
          if [ $fileUploadCount -gt 0 ]; then
             while read line
                do
                   echo $line 
                   cp -R $line $DCM_LOG_PATH
                   done < $DCM_UPLOAD_LIST
                   copyOptLogsFiles
                   cat /dev/null > $DCM_UPLOAD_LIST	
                   uploadDCMLogs
          else
             copyOptLogsFiles
             uploadDCMLogs
          fi
       else 
          touch $DCM_INDEX
          copyAllFiles
          uploadDCMLogs
       fi
    fi
fi 
if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
    then
        if [ "$maintenance_error_flag" -eq 1 ]
        then
            MAINT_LOGUPLOAD_ERROR=5
            eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_ERROR
        else
            MAINT_LOGUPLOAD_COMPLETE=4
            eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_COMPLETE
        fi
fi
if [ ! -f /etc/os-release ];then pidCleanup;fi


#!/bin/busybox sh
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
. /etc/device.properties
if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
     . /lib/rdk/getSecureDumpStatus.sh
fi

if [ -f /etc/os-release ]; then
    CORE_PATH=$CORE_PATH
fi
## DEPRECATED!!!
# WARNING! THIS FILE IS DEPRECATED AND WILL BE REMOVED IN FUTURE RELEASES!
# PLEASE DON'T CHANGE IT!
# uploadDumps.sh IS NOW IN crashupload REPOSITORY!


#Uploads coredumps to an ftp server if there are any
. /etc/include.properties
. $RDK_PATH/utils.sh

S3BUCKETURL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.CrashUpload.S3BucketUrl 2>&1)
PROD_CRASHURL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.CrashUpload.crashPortalPRODUrl 2>&1)
VBN_CRASHURL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.CrashUpload.crashPortalVBNUrl 2>&1)
DEV_CRASHURL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.CrashUpload.crashPortalDEVUrl 2>&1)

if [[ -z $S3BUCKETURL || -z $PROD_CRASHURL || -z $VBN_CRASHURL || -z $DEV_CRASHURL ]]; then
    S3BUCKETURL="s3.amazonaws.com"
    PROD_CRASHURL="crashportal.ccp.xcal.tv"
    VBN_CRASHURL="vbn.crashportal.ccp.xcal.tv"
    DEV_CRASHURL="crashportal.dt.ccp.cable.comcast.com"
fi
S3BUCKET="ccp-stbcrashes"

export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

if [ "$DEVICE_TYPE" != "mediaclient" ]; then
     . $RDK_PATH/commonUtils.sh
fi

CORE_LOG="$LOG_PATH/core_log.txt"

if [[ ! -f $CORE_LOG ]]; then
    touch $CORE_LOG
    chmod a+w $CORE_LOG
fi

# Usage: echo "debug information" | logStdout
# This function is needed because if we would try smth like "echo 'debug' >> $LOG"
# and we wouldn't have write access rights on $LOG, 'echo' wouldn't execute
logStdout()
{
    while read line; do
        logMessage "${line}"
    done
}

# Locking functions
# If you want to leave the script earlier than EOF, you should insert
# remove_lock $LOCK_DIR_PREFIX
# before you leave.
create_lock_or_exit()
{
    path="$1"
    while true; do
        if [[ -d "${path}.lock.d" ]]; then
            logMessage "Script is already working. ${path}.lock.d. Skip launch another instance..."
            exit 0
        fi
        mkdir "${path}.lock.d" || logMessage "Error creating ${path}.lock.d"
        break;
    done
}

remove_lock()
{
    path="$1"
    if [ -d "${path}.lock.d" ]; then
        rmdir "${path}.lock.d" || logMessage "Error deleting ${path}.lock.d"
    fi
}

POTOMAC_USER=ccpstbscp
POTOMAC_IDENTITY_FILE=/.ssh/id_dropbear

# Assign the input arguments
CRASHTS=$1
DUMP_FLAG=$2
TIMESTAMP_DEFAULT_VALUE="2000-01-01-00-00-00"
SHA1_DEFAULT_VALUE="0000000000000000000000000000000000000000"
MAC_DEFAULT_VALUE="000000000000"
MODEL_NUM_DEFAULT_VALUE="UNKNOWN"

logMessage()
{
    message="$1"
    echo "[PID:$$ `date -u +%Y/%m/%d-%H:%M:%S`]: $message" >> $CORE_LOG
}

sanitize()
{
   toClean="$1"
   # remove all except alphanumerics and some symbols
   # don't use stmh like ${toClean//[^\/a-zA-Z0-9 :+,]/} \
   # here since it doesn't work with slash (due to old busybox version, probably)
   clean=`echo "$toClean"|sed -e 's/[^/a-zA-Z0-9 :+._,=-]//g'`
   echo "$clean"
}

uploadToS3()
{
    file=$1

    EnableOCSPStapling="/tmp/.EnableOCSPStapling"
    EnableOCSP="/tmp/.EnableOCSPCA"
    logMessage "uploadToS3 $1"

    app=${file%%.signal*}
    app=${app##*_}

    #get signed parameters from server
    OIFS=$IFS
    IFS=$'\n'

    ##sets positional variables $1, $2... Please don't quote this additionally unless you really know what you are doing
    if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
        set -- `curl -s --cert-status \
                                             --data-urlencode "source=$file"\
                                             --data-urlencode "dumptype=core"\
                                             --data-urlencode "mod=$modNum"\
                                             --data-urlencode "app=$app" \
                                             --data-urlencode "buildtype=$BUILD_TYPE"\
                                             "https://${PROD_CRASHURL}:8090/cgi-bin/sign.py"`
    else
       set -- `curl -s --data-urlencode "source=$file"\
                                            --data-urlencode "dumptype=core"\
                                            --data-urlencode "mod=$modNum"\
                                            --data-urlencode "app=$app" \
                                            --data-urlencode "buildtype=$BUILD_TYPE"\
                                            "https://${PROD_CRASHURL}:8090/cgi-bin/sign.py"`
    fi

    if [ $? -ne 0 ]; then
        logMessage "Curl finished unsuccessfully! Error code: $?"
    fi

    IFS=$OIFS

    #make params shell-safe
    validDate=`sanitize "$1"`
    auth=`sanitize "$2"`
    remotePath=`sanitize "$3"`

    logMessage "Safe params: $validDate -- $auth -- $remotePath"

    if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
        nice -n 19 curl --cert-status -X PUT -T "$WORKING_DIR/$file" -H "Host: $S3BUCKET.$S3BUCKETURL" -H "Date: $validDate" -H "Content-Type: application/x-compressed-tar" -H "Authorization: AWS $auth" "https://$S3BUCKET.$S3BUCKETURL/${remotePath}" |logStdout
    else
        nice -n 19 curl -X PUT -T "$WORKING_DIR/$file" -H "Host: $S3BUCKET.$S3BUCKETURL" -H "Date: $validDate" -H "Content-Type: application/x-compressed-tar" -H "Authorization: AWS $auth" "https://$S3BUCKET.$S3BUCKETURL/${remotePath}" |logStdout
    fi

    if [ $? -ne 0 ]; then
        logMessage "Curl finished unsuccessfully! Error code: $?"
    fi

}


checkParameter()
{
    local paramName=\$"$1"
    local evaluatedValue=`eval "expr \"$paramName\" "`
    if [ -z $evaluatedValue ] ; then
        case "$1" in
        sha1)
            logMessage "SHA1 is empty. Setting default value."
            eval "$1=$SHA1_DEFAULT_VALUE"
            ;;
        modNum)
            logMessage "Model num is empty. Setting default value."
            eval "$1=$MODEL_NUM_DEFAULT_VALUE"
            ;;
        *TS)
            logMessage "Timestamp is empty. Setting default value."
            eval "$1=$TIMESTAMP_DEFAULT_VALUE"
            ;;
        esac
    fi
}

checkMAC()
{
    if [ -z "$MAC" ] ; then
        logMessage "MAC address is empty. Trying to get it again, including network interfaces currently down."
        MAC=`getMacAddressOnly`
        if [ -z "$MAC" ] ; then
            logMessage "MAC address is still empty. Setting to default value."
            MAC=$MAC_DEFAULT_VALUE
            logMessage "Output of ifconfig:"
            ifconfig -a 2>&1 | logStdout
        fi
    else
        # forcibly take to UPPER case and remove colons if present
        MAC=`echo "$MAC" | tr a-f A-F | sed -e 's/://g'`
    fi
}

if [ "$DUMP_FLAG" = "1" ] ; then
    logMessage "starting coredump processing"
    WORKING_DIR="$CORE_PATH"
    DUMPS_EXTN=*core.prog*.gz
    TARBALLS=*.core.tgz
    #to limit this to only one instance at any time..
    LOCK_DIR_PREFIX="/tmp/.uploadCoredumps"
    CRASH_PORTAL_PATH="/opt/crashportal_uploads/coredumps/"
    count=`ls $WORKING_DIR/$DUMPS_EXTN 2>/dev/null | wc -l`
    if [ ! $count ]; then logMessage "No coredumps for uploading" ; exit 1 ; fi
else
    logMessage "starting minidump processing"
    WORKING_DIR="$MINIDUMPS_PATH"
    DUMPS_EXTN=*.dmp
    TARBALLS=*.dmp.tgz
    CRASH_PORTAL_PATH="/opt/crashportal_uploads/minidumps/"
    count=`ls $WORKING_DIR/$DUMPS_EXTN 2> /dev/null | wc -l`
    #to limit this to only one instance at any time..
    LOCK_DIR_PREFIX="/tmp/.uploadMinidumps"
    if [ ! $count ]; then logMessage "No minidumps for uploading" ; exit 1; fi
fi

if [ "$BUILD_TYPE" = "prod" ]; then
    PORTAL_URL="$PROD_CRASHURL"
elif [ "$BUILD_TYPE" = "vbn" ]; then
    PORTAL_URL="$VBN_CRASHURL"
elif [ "$BUILD_TYPE" = "dev" ]; then
    PORTAL_URL="$DEV_CRASHURL"
else
    # Lab2 crashportal
    PORTAL_URL="162.150.27.194"
fi

create_lock_or_exit $LOCK_DIR_PREFIX

# Upon exit, remove locking
trap "{ remove_lock $LOCK_DIR_PREFIX ; }" EXIT

logMessage "Portal URL: $PORTAL_URL"

coreUpload()
{
    coreFile=$1
    host=$2
    remotePath=$3

    dirnum=$(($RANDOM%100))
    if [ "$dirnum" -ge "0" -a "$dirnum" -le "9" ]; then
        dirnum="0$dirnum"
    fi

    logMessage "Upload string: scp -i $POTOMAC_IDENTITY_FILE ./$coreFile $POTOMAC_USER@$host:$remotePath/$dirnum/"
    nice -n 19 scp -i $POTOMAC_IDENTITY_FILE "./$coreFile" "$POTOMAC_USER"@$host:$remotePath/$dirnum/ 2>&1 | logStdout

    if [ $? -eq 0 ]; then
        logMessage "Success uploading file: $coreFile to $host:$remotePath/$dirnum/."
    else
        logMessage "Uploading to the Server failed.."
    fi

    # It's temporary; just for field tests on VBN builds
     if [ "$DUMP_FLAG" = "1" ]; then
         if [ "x$BUILD_TYPE" = "xvbn" -o "x$BUILD_TYPE" = "xprod" ]; then
            uploadToS3 "$coreFile"
         fi
     fi

    logMessage "removing $WORKING_DIR/$coreFile"
    rm -rf $WORKING_DIR/$coreFile
}

RECEIVER="/mnt/nfs/env/Receiver"
VERSION_FILE="version.txt"
boxType=$BOX_TYPE
modNum=$MODEL_NUM
# Ensure modNum is not empty
checkParameter modNum

if [ "$BUILD_TYPE" != "prod" ]; then
# if the build type is DEV or VBN we should add all logs to the package
    #Receiver Logs
    STBLOG_FILE=$LOG_PATH/receiver.log
    #OCAP Logs
    OCAPLOG_FILE=$LOG_PATH/ocapri_log.txt
    #Thread dump
    THREAD_DUMP=threaddump.txt
    #Message.txt
    MESSAGE_TXT=$LOG_PATH/messages.txt
    #app_status.log
    APP_STATUS_LOG=$LOG_PATH/app_status_backup.log
else
    if [ "$DUMP_FLAG" != "1" ]; then
    # if the build type is PROD and script is in minidump's mode we should add receiver log only
        #Receiver Logs
        STBLOG_FILE=/opt/logs/receiver.log
    fi
fi

# Get the MAC address of the box
MAC=`getMacAddressOnly`
# Ensure MAC is not empty
checkMAC

# Receiver binary is used to calculate SHA1 marker which is used to find debug file for the coredumps
sha1=`getSHA1 $RECEIVER`
# Ensure sha1 is not empty
checkParameter sha1

if [ ! -z "$STBLOG_FILE" -a -f "$STBLOG_FILE" ]; then
    stbModTS=`getLastModifiedTimeOfFile $STBLOG_FILE`
    # Ensure timestamp is not empty
    checkParameter stbModTS
    stbLogFile=`setLogFile $sha1 $MAC $stbModTS $boxType $modNum $STBLOG_FILE`
fi
if [ ! -z "$OCAPLOG_FILE" -a -f "$OCAPLOG_FILE" ]; then
    ocapLogModTS=`getLastModifiedTimeOfFile $OCAPLOG_FILE`
    # Ensure timestamp is not empty
    checkParameter ocapLogModTS
    ocapLogFile=`setLogFile $sha1 $MAC $ocapLogModTS $boxType $modNum $OCAPLOG_FILE`
fi
if [ ! -z "$APP_STATUS_LOG" -a -f "$APP_STATUS_LOG" ] ; then
    appStatusLogModTS=`getLastModifiedTimeOfFile $APP_STATUS_LOG`
    # Ensure timestamp is not empty
    checkParameter appStatusLogModTS
    appStatusLogFile=`setLogFile $sha1 $MAC $appStatusLogModTS $boxType $modNum $APP_STATUS_LOG`
fi
if [ ! -z "$MESSAGE_TXT" -a -f "$MESSAGE_TXT" ]; then
     messagesTxtModTS=`getLastModifiedTimeOfFile $MESSAGE_TXT`
     # Ensure timestamp is not empty
     checkParameter messagesTxtModTS
     messagesTxtFile=`setLogFile $sha1 $MAC $messagesTxtModTS $boxType $modNum $MESSAGE_TXT`
fi

# use for loop read all nameservers
logFileCopy()
{
    APPNDR=""
    if [ "$1" == "1" ]; then
        APPNDR="_mpeos_main"
    fi
    if [ ! -z "$STBLOG_FILE" -a -f "$STBLOG_FILE$APPNDR" ]; then
        cp $STBLOG_FILE$APPNDR $stbLogFile
    fi
    if [ ! -z "$OCAPLOG_FILE" -a -f "$OCAPLOG_FILE$APPNDR" ]; then
        cp $OCAPLOG_FILE$APPNDR $ocapLogFile
    fi
    if [ ! -z "$MESSAGE_TXT" -a -f "$MESSAGE_TXT$APPNDR" ]; then
        cp $MESSAGE_TXT$APPNDR $messagesTxtFile
    fi
    if [ ! -z "$APP_STATUS_LOG" -a -f "$APP_STATUS_LOG$APPNDR" ]; then
        cp $APP_STATUS_LOG$APPNDR $appStatusLogFile
    fi
}

if [ ! -d $WORKING_DIR ]; then exit 0; fi
cd $WORKING_DIR

shouldProcessFile()
{
    fName=$1
    # always upload minidumps
    if [ "$DUMP_FLAG" != "1" ]; then
        echo 'true'
        return
    # upload cores even for prod if it is not Receiver
    elif [[ -n "${fName##*Receiver*}" ]]; then
        echo 'true'
        return
    # upload cores not for prod
    elif [ "$BUILD_TYPE" != "prod" ]; then
        echo 'true'
        return
    else
    # it's prod coredump, not mpeos and not discovery
    logMessage "Not processing $fName"
        echo 'false'
        return
    fi
}

# wait for app buffers are flushed
type flushLogger &> /dev/null && flushLogger || sleep 2

for f in $DUMPS_EXTN
do
   if [ -f "$f" ]; then
        #last modification date of a core dump, to ease refusing of already uploaded core dumps on a server side
        modDate=`getLastModifiedTimeOfFile $f`
        if [ -z "$CRASHTS" ]; then
              CRASHTS=$modDate
              # Ensure timestamp is not empty
              checkParameter CRASHTS
        fi

        if [ "$DUMP_FLAG" == "1" ] ; then
            if echo $f | grep -q mpeos-main; then
                #CRASHTS not reqd as minidump won't be uploaded for mpeos-main
                dumpName=`setLogFile $sha1 $MAC $modDate $boxType $modNum $f`
                logFileCopy 1
            else
                logFileCopy 0
                dumpName=`setLogFile $sha1 $MAC $CRASHTS $boxType $modNum $f`
            fi
	if [ "$SEC_DUMP" = "true" ]; then
		if [ "${#dumpName}" -ge "135" ]; then
		#Removing the HEADER of the corefile due to ecryptfs limitation as file can't be open when it exceeds 140 characters.
		dumpName="${dumpName#*_}"
		fi
	fi
            tgzFile=$dumpName".core.tgz"
        else
            dumpName=`setLogFile $sha1 $MAC $CRASHTS $boxType $modNum $f`
	if [ "$SEC_DUMP" = "true" ]; then
		if [ "${#dumpName}" -ge "135" ]; then
		#Removing the HEADER of the corefile due to ecryptfs limitation as file can't be open when it exceeds 140 characters.
		dumpName="${dumpName#*_}"
		fi
	fi
            logFileCopy 0
            tgzFile=$dumpName".tgz"
        fi

        mv $f $dumpName
        cp "/"$VERSION_FILE .

        if [ "$DUMP_FLAG" == "1" ] ; then
            nice -n 19 tar -zcvf $tgzFile $dumpName $stbLogFile $ocapLogFile $messagesTxtFile $appStatusLogFile $VERSION_FILE $CORE_LOG 2>&1 | logStdout
            if [ $? -eq 0 ]; then
                logMessage "Success Compressing the files, $tgzFile $dumpName $stbLogFile $ocapLogFile $messagesTxtFile $appStatusLogFile $VERSION_FILE $CORE_LOG "
            else
                logMessage "Compression Failed ."
            fi

            if [ -f $tgzFile".txt" ]; then rm $tgzFile".txt"; fi
            if [ ! -z "$STBLOG_FILE" -a -f $STBLOG_FILE"_mpeos-main" ]; then
                rm $STBLOG_FILE"_mpeos-main"
            fi
            if [ ! -z "$OCAPLOG_FILE" -a -f $OCAPLOG_FILE"_mpeos-main" ]; then
                rm $OCAPLOG_FILE"_mpeos-main"
            fi
            if [ ! -z "$MESSAGE_TXT" -a -f $MESSAGE_TXT"_mpeos-main" ]; then
                rm $MESSAGE_TXT"_mpeos-main"
            fi
            if [ ! -z "$APP_STATUS_LOG" -a -f $APP_STATUS_LOG"_mpeos-main" ]; then
                rm $APP_STATUS_LOG"_mpeos-main"
            fi
        else
            files="$tgzFile $dumpName $VERSION_FILE $stbLogFile $ocapLogFile $messagesTxtFile $appStatusLogFile $CORE_LOG"
            if [ "$BUILD_TYPE" != "prod" ]; then
                test -f $LOG_PATH/receiver.log && files="$files $LOG_PATH/receiver.log*"
                test -f $LOG_PATH/thread.log && files="$files $LOG_PATH/thread.log"
            else
                test -f $LOG_PATH/receiver.log && files="$files $LOG_PATH/receiver.log"
                test -f $LOG_PATH/receiver.log.1 && files="$files $LOG_PATH/receiver.log.1"
            fi
            nice -n 19 tar -zcvf $files 2>&1 | logStdout
            if [ $? -eq 0 ]; then
                logMessage "Success Compressing the files $files"
            else
                logMessage "Compression Failed."
            fi
        fi

        rm $dumpName
        if [ ! -z "$STBLOG_FILE" -a -f "$STBLOG_FILE" ]; then
            logMessage "Removing $stbLogFile"
            rm $stbLogFile
        fi
        if [ ! -z "$OCAPLOG_FILE" -a -f "$OCAPLOG_FILE" ]; then
            logMessage "Removing $ocapLogFile"
            rm $ocapLogFile
        fi
        if [ ! -z "$MESSAGE_TXT" -a -f "$MESSAGE_TXT" ]; then
            logMessage "Removing $messagesTxtFile"
            rm $messagesTxtFile
        fi
        if [ ! -z "$APP_STATUS_LOG" -a -f "$APP_STATUS_LOG" ]; then
            logMessage "Removing $appStatusLogFile"
            rm $appStatusLogFile
        fi
        if [ -f $WORKING_DIR"/"$VERSION_FILE ]; then
            logMessage "Removing ${WORKING_DIR}/${VERSION_FILE}"
            rm $WORKING_DIR"/"$VERSION_FILE
        fi
   fi
done

if [ "$DUMP_FLAG" != "1" ]; then
    rm -f $LOG_PATH/thread.log
fi

for f in $TARBALLS
do
    if [ -f $f ]; then
        # if it is not Receiver, and build type is prod
        if [[ $DUMP_FLAG = "1" && "$BUILD_TYPE" = "prod" && -n "${f##*Receiver*}" ]]; then
            # upload to S3
            uploadToS3 "$f"
            logMessage "removing $WORKING_DIR/$f"
            rm -rf $WORKING_DIR/$f
        else
            logMessage "trying to upload tarball $f"
            # This is for SCP/DBCLIENT to find /.ssh/ dir
            export HOME=/
            coreUpload $f $PORTAL_URL $CRASH_PORTAL_PATH
        fi
    fi
done

remove_lock $LOCK_DIR_PREFIX


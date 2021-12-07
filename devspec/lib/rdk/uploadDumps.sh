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

. /etc/device.properties

#Uploads coredumps to an ftp server if there are any
. /etc/include.properties
. $RDK_PATH/utils.sh
. $RDK_PATH/commonUtils.sh

CORE_LOG="$LOG_PATH/core_log.txt"

# Locking functions
# If you want to leave the script earlier than EOF, you should insert
# remove_lock $LOCK_DIR_PREFIX >> $CORE_LOG 2>> $CORE_LOG
# before you leave.
create_lock_or_wait()
{
    path="$1"
    wait_time="${2:-60}"
    while true; do
        if mkdir -p "${path}.lock.d"; then
            break;
        fi
        sleep $wait_time
    done
}

remove_lock()
{
    path="$1"
    rmdir "${path}.lock.d"
}
if [ "true" != ${RDK_EMULATOR} ]; then
POTOMAC_USER=ccpstbscp
fi
if [ "true" != ${RDK_EMULATOR} ]; then
POTOMAC_IDENTITY_FILE=/.ssh/id_dropbear
fi

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
    echo "[`date -u +%Y/%m/%d-%I:%M`]: $message" >> $CORE_LOG
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
            ifconfig -a >> $CORE_LOG
        fi
    else
        # forcibly take to UPPER case and remove colons if present
        MAC=`echo "$MAC" | tr a-f A-F | sed -e 's/://g'`
    fi
}
if [ "true" = "$RDK_EMULATOR" ] ; then
logMessage "==================Entering UploadDumps.sh=========================="
fi
if [ "$DUMP_FLAG" = "1" ] ; then
    WORKING_DIR="$CORE_PATH"
    DUMPS_EXTN=*core.prog*.gz
    TARBALLS=*.tgz
    #to limit this to only one instance at any time..
    LOCK_DIR_PREFIX="/tmp/.uploadCoredumps"
    CRASH_PORTAL_PATH="/opt/crashportal_uploads/coredumps/"
    count=`ls $WORKING_DIR/$DUMPS_EXTN 2>/dev/null | wc -l`
    if [ "true" == $RDK_EMULATOR ]; then
    echo "Total Core Dumps file in $WORKING_DIR=$count" >> $CORE_LOG
    fi
    if [ ! $count ]; then logMessage "No coredumps for uploading" ; exit 1 ; fi
else
    WORKING_DIR="/opt/minidumps"
    DUMPS_EXTN=*.dmp
    TARBALLS=*.dmp.tgz
    CRASH_PORTAL_PATH="/opt/crashportal_uploads/minidumps/"
    count=`ls $WORKING_DIR/$DUMPS_EXTN 2> /dev/null | wc -l`
    #to limit this to only one instance at any time..
    LOCK_DIR_PREFIX="/tmp/.uploadMinidumps"
    if [ ! $count ]; then logMessage "No minidumps for uploading" ; exit 1; fi
fi

if [ "$BUILD_TYPE" = "prod" ]; then
    PORTAL_URL=" "
elif [ "$BUILD_TYPE" = "vbn" ]; then
    PORTAL_URL=" "
elif [ "$BUILD_TYPE" = "dev" ]; then
    if [ "true" != $RDK_EMULATOR ]; then
    	PORTAL_URL=" "
    else
        PORTAL_URL=$CRASH_PORTAL_SERVER
    fi
else
    # Lab2 crashportal
    PORTAL_URL=" "
fi

logMessage "Portal URL: $PORTAL_URL"

create_lock_or_wait $LOCK_DIR_PREFIX >> $CORE_LOG 2>> $CORE_LOG

coreUpload()
{
   
    coreFile=$1
    host=$2
    path=$3

    logMessage "Upload string: scp -i $POTOMAC_IDENTITY_FILE ./$coreFile $POTOMAC_USER@$host:$path"
    if [ "true" != $RDK_EMULATOR ]; then
    	nice -n 19 scp -i $POTOMAC_IDENTITY_FILE "./$coreFile" "$POTOMAC_USER"@$host:$path >> $CORE_LOG 2>> $CORE_LOG
    else
    	logMessage "scp -i $POTOMAC_IDENTITY_FILE "$coreFile" "$POTOMAC_USER"@$host:$path "
	export HOME=/home/root
    	scp -i $POTOMAC_IDENTITY_FILE "$coreFile" "$POTOMAC_USER"@$host:$path >> $CORE_LOG 2>> $CORE_LOG
    fi

    if [ $? -eq 0 ]; then
        logMessage "Success uploading file: $coreFile to $host:$path."
    else
        logMessage "Uploading to the Server failed.."
    fi

    rm -rf $WORKING_DIR/$coreFile
}
if [ "true" != $RDK_EMULATOR ]; then
RECEIVER="/mnt/nfs/env/Receiver"
VERSION_FILE="version.txt"
boxType=$BOX_TYPE
modNum=$MODEL_NUM
# Ensure modNum is not empty
checkParameter modNum
fi

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
if [ "true" != $RDK_EMULATOR ]; then
# Receiver binary is used to calculate SHA1 marker which is used to find debug file for the coredumps
sha1=`getSHA1 $RECEIVER`
# Ensure sha1 is not empty
checkParameter sha1

if [ ! -z "$STBLOG_FILE" -a -f $STBLOG_FILE ]; then
    stbModTS=`getLastModifiedTimeOfFile $STBLOG_FILE`
    # Ensure timestamp is not empty
    checkParameter stbModTS
    stbLogFile=`setLogFile $sha1 $MAC $stbModTS $boxType $modNum $STBLOG_FILE`
fi
if [ ! -z "$OCAPLOG_FILE" -a -f $OCAPLOG_FILE ]; then
    ocapLogModTS=`getLastModifiedTimeOfFile $OCAPLOG_FILE`
    # Ensure timestamp is not empty
    checkParameter ocapLogModTS
    ocapLogFile=`setLogFile $sha1 $MAC $ocapLogModTS $boxType $modNum $OCAPLOG_FILE`
fi
if [ ! -z "$APP_STATUS_LOG" -a -f $APP_STATUS_LOG ] ; then
    appStatusLogModTS=`getLastModifiedTimeOfFile $APP_STATUS_LOG`
    # Ensure timestamp is not empty
    checkParameter appStatusLogModTS
    appStatusLogFile=`setLogFile $sha1 $MAC $appStatusLogModTS $boxType $modNum $APP_STATUS_LOG`
fi
if [ ! -z "$MESSAGE_TXT" -a -f $MESSAGE_TXT ]; then
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
    if [ ! -z "$STBLOG_FILE" -a -f $STBLOG_FILE$APPNDR ]; then
        cp $STBLOG_FILE$APPNDR $stbLogFile
    fi
    if [ ! -z "$OCAPLOG_FILE" -a -f $OCAPLOG_FILE$APPNDR ]; then
        cp $OCAPLOG_FILE$APPNDR $ocapLogFile
    fi
    if [ ! -z "$MESSAGE_TXT" -a -f $MESSAGE_TXT$APPNDR ]; then
        cp $MESSAGE_TXT$APPNDR $messagesTxtFile
    fi
    if [ ! -z "$APP_STATUS_LOG" -a -f $APP_STATUS_LOG$APPNDR ]; then
        cp $APP_STATUS_LOG$APPNDR $appStatusLogFile
    fi
}
fi
if [ ! -d $WORKING_DIR ]; then exit 0; fi
cd $WORKING_DIR

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
	    if [ "true" != $RDK_EMULATOR ]; then
            tgzFile=$dumpName".core.tgz"
	    else
	     tgzFile=$f".tgz"
	    fi
        else
            dumpName=`setLogFile $sha1 $MAC $CRASHTS $boxType $modNum $f`
            logFileCopy 0
	    if [ "true" != $RDK_EMULATOR ]; then
            	tgzFile=$dumpName".tgz"
	    else
	     	tgzFile=$f".tgz"
	    fi
        fi
	if [ "true" != $RDK_EMULATOR ]; then
        mv $f $dumpName
        cp "/"$VERSION_FILE .
	fi

        if [ "$DUMP_FLAG" == "1" ] ; then
	    if [ "true" != $RDK_EMULATOR ]; then
            	nice -n 19 tar -zcvf $tgzFile $dumpName $stbLogFile $ocapLogFile $messagesTxtFile $appStatusLogFile $VERSION_FILE >> $CORE_LOG 2>> $CORE_LOG
	    else
		    tar -zcvf $tgzFile $f  >> $CORE_LOG 2>> $CORE_LOG
	    fi
            if [ $? -eq 0 ]; then
	      if [ "true" != $RDK_EMULATOR ]; then
                logMessage "Success Compressing the files, $tgzFile $dumpName $stbLogFile $ocapLogFile $messagesTxtFile $appStatusLogFile $VERSION_FILE "
	      else
                logMessage "Success Compressing the files, $tgzFile"
	      fi
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
	    if [ "true" != $RDK_EMULATOR ]; then
            nice -n 19 tar -zcvf $tgzFile $dumpName $VERSION_FILE $stbLogFile $ocapLogFile $messagesTxtFile $appStatusLogFile >> $CORE_LOG 2>> $CORE_LOG
	    else
                tar -zcvf $tgzFile $f >> $CORE_LOG 2>> $CORE_LOG
            fi

            if [ $? -eq 0 ]; then
                logMessage "Success Compressing the files, $tgzFile $dumpName $VERSION_FILE $stbLogFile $ocapLogFile $messagesTxtFile $appStatusLogFile "
            else
               logMessage "Compression Failed ."
            fi
        fi

        rm $dumpName
        if [ ! -z "$STBLOG_FILE" -a -f $STBLOG_FILE ]; then
            rm $stbLogFile
        fi
        if [ ! -z "$OCAPLOG_FILE" -a -f $OCAPLOG_FILE ]; then
            rm $ocapLogFile
        fi
        if [ ! -z "$MESSAGE_TXT" -a -f $MESSAGE_TXT ]; then
            rm $messagesTxtFile
        fi
        if [ ! -z "$APP_STATUS_LOG" -a -f $APP_STATUS_LOG ]; then
            rm $appStatusLogFile
        fi
        if [ -f $WORKING_DIR"/"$VERSION_FILE ]; then
            rm $WORKING_DIR"/"$VERSION_FILE
        fi
   fi
done

for f in $TARBALLS
do
    if [ -f $f ]; then
         logMessage "trying to upload tarball $f"
         # This is for SCP/DBCLIENT to find /.ssh/ dir
         export HOME=/
         coreUpload $f $PORTAL_URL $CRASH_PORTAL_PATH
    fi
done

if [ -f $RDK_PATH/clearCoredumps.sh ] ; then
    if [ "true" != $RDK_EMULATOR ]; then
     nice -n 19 $RDK_PATH/clearCoredumps.sh &
    else
     sh $RDK_PATH/clearCoredumps.sh &
    fi
fi
remove_lock $LOCK_DIR_PREFIX >> $CORE_LOG 2>> $CORE_LOG


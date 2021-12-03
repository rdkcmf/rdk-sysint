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
## Script to start uploadSTBLogs script.
##################################################################

. /etc/include.properties
. /etc/device.properties

if [ "$BUILD_TYPE" != "prod" ] && [ -f /opt/dcm.properties ]; then
      . /opt/dcm.properties
else
      . /etc/dcm.properties
fi

. /lib/rdk/utils.sh

export PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/sbin:/usr/local/lighttpd/sbin:/usr/local/sbin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/Qt/lib:/usr/local/lib
 

#--------------------------------------------------------------------------------------------
# Arguments 
#--------------------------------------------------------------------------------------------

#if any arguments can be added here

#---------------------------------------------------------------------------------------------
# Variables
#---------------------------------------------------------------------------------------------
useXpkiMtlsLogupload=false

reboot_flag=0  # same as dcm log service
tftp_server=$LOG_SERVER # from dcm.properties

#---------------------------------------------------------------------------------------------
# Functions
#---------------------------------------------------------------------------------------------
checkXpkiMtlsBasedLogUpload()
{
    if [ "$DEVICE_TYPE" = "broadband" ]; then
        dycredpath="/nvram/lxy"
    else
        dycredpath="/opt/lxy"
    fi

    if [ -d $dycredpath ] && [ -f /usr/bin/rdkssacli ] && [ -f /opt/certs/devicecert_1.pk12 ]; then
        useXpkiMtlsLogupload="true"
    else
        useXpkiMtlsLogupload="false"
    fi
    echo "`/bin/timestamp` xpki based mtls support = $useXpkiMtlsLogupload" >> $LOG_PATH/dcmscript.log
}

#--------------------------------------------------------------------------------------------
# Main App
#--------------------------------------------------------------------------------------------
 upload_protocol=`cat /tmp/DCMSettings.conf | grep 'LogUploadSettings:UploadRepository:uploadProtocol' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
 if [ -n "$upload_protocol" ]; then
     echo "`/bin/timestamp` upload_protocol: $upload_protocol" >> $LOG_PATH/dcmscript.log
 else
     upload_protocol='HTTP'
     echo "`/bin/timestamp` 'urn:settings:LogUploadSettings:Protocol' is not found in DCMSettings.conf" >> $LOG_PATH/dcmscript.log
 fi


 if [ "$upload_protocol" == "HTTP" ]; then
     httplink=`cat /tmp/DCMSettings.conf | grep 'LogUploadSettings:UploadRepository:URL' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
     if [ -z "$httplink" ]; then
         echo "`/bin/timestamp` 'LogUploadSettings:UploadRepository:URL' is not found in DCMSettings.conf, upload_httplink is '$upload_httplink'" >> $LOG_PATH/dcmscript.log
     else
         upload_httplink=$httplink
         echo "`/bin/timestamp` upload_httplink is $upload_httplink" >> $LOG_PATH/dcmscript.log
     fi
     echo "MTLS preferred" >> $LOG_PATH/dcmscript.log
     checkXpkiMtlsBasedLogUpload
     #sky endpoint dont use the /secure extension;
     if [ "$FORCE_MTLS" != "true"  ]; then
         upload_httplink=`echo $httplink | sed "s|/cgi-bin|/secure&|g"`
     fi
     echo "`/bin/timestamp` upload_httplink is $upload_httplink" >> $LOG_PATH/dcmscript.log
 fi


 uploadCheck=`cat /tmp/DCMSettings.conf | grep 'urn:settings:LogUploadSettings:UploadOnReboot' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
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
	 nice  -n 19 /bin/busybox sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 1 0 $upload_protocol $upload_httplink &
 fi

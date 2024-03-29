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

# initialize partnerId
. $RDK_PATH/getPartnerId.sh

# initialize accountId
. $RDK_PATH/getAccountId.sh

T2_0_APP="telemetry2_0"
# Input for random sleep time calculation
sleep_time=$1
# 0 indicates to store the information .
# 1 indicates to send information onto cloud.
# 2 indicates to store the information while deepsleep triggered.
# 3 indicates to send T2 information onto cloud prior to (LOG_UPLOAD) - Marker seek values will be reset
# 4 - None {Leaving void to make consistent with number for log upload on demand}
# 5 - indicates T2 to generate a report and send immediately to cloud. Marker seek values will not be reset
#     Interface is exected to be used by AS/UI prior to deep sleep or forced request/reboot from UI
sendInformation=$2

if [ "$sendInformation" -eq 3 ] || [ "$sendInformation" -eq 5 ]; then
    T2_ENABLE="$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.Telemetry.Enable 2>&1 > /dev/null)"
    if [ -z "$T2_ENABLE" ]; then
        T2_ENABLE="`rbuscli getvalues Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.Telemetry.Enable | grep Value | awk '{print $3}'`"
    fi
    echo "RFC value for Telemetry 2.0 Enable is $T2_ENABLE ."
    if [ "x$T2_ENABLE" = "xtrue" ] || [ "$T2_ENABLE" = "1" ]; then
         t2Pid=`pidof $T2_0_APP`
         echo "$t2Pid"
         if [ ! -z  "$t2Pid" ]; then
            if [ "$sendInformation" -eq 3 ]; then
                echo "Send signal 10 to $T2_0_APP to trigger report genertaion prior to log upload with external triggers like service manager api"
                kill -10 $t2Pid
            fi
            if [ "$sendInformation" -eq 5 ]; then
                echo "Send signal 29 to $T2_0_APP to trigger on demand report generation with external triggers like service manager api"
                kill -29 $t2Pid
            fi
         fi
    else
        echo "Telemetry 2.0 is not enabled. On demand report generation is not supported in legacy dca telemetry"
    fi
    exit 0;
fi

LOCKFILE=/tmp/`basename $0`.lock
if [ -e ${LOCKFILE} ] && kill -0 `cat ${LOCKFILE}`; then
    echo "$0 is already running"
    flag=1
    if [ "$sendInformation" != "2" ]; then
        echo "$0 Exiting dca_utility.DeepSleep triggered"
        exit 0;
    fi
fi

# make sure the lockfile is removed when we exit
trap "rm -f ${LOCKFILE}; exit 0" INT TERM EXIT

#claim the lockfile
echo $$ > ${LOCKFILE}

TELEMETRY_PATH="/opt/.telemetry"
TELEMETRY_PATH_TEMP="$TELEMETRY_PATH/tmp"

RTL_LOG_FILE="$LOG_PATH/dcmscript.log"
TLS_LOG_FILE="$LOG_PATH/tlsError.log"
RTL_TEMP_LOG_FILE="$RAMDISK_PATH/.rtl_temp.log"

# Files required to be generated once per boot-up session
MAP_PATTERN_CONF_FILE="$TELEMETRY_PATH/dcafile.conf"
TEMP_PATTERN_CONF_FILE="$TELEMETRY_PATH/temp_dcafile.conf"
SORTED_PATTERN_CONF_FILE="$TELEMETRY_PATH/dca_temp_file.conf"
EXEC_COUNTER_FILE="/tmp/.dcaCounter.txt"

MAX_RETRY_ATTEMPTS=12

# Intermediate files for curl processing
HTTP_FILENAME="$TELEMETRY_PATH/dca_httpresult.txt"
HTTP_CODE="$TELEMETRY_PATH/dca_curl_httpcode"

# Custom binaries which are less memory expensive
DCA_BINARY="/usr/bin/dca"

TELEMETRY_RESEND_FILE="/opt/.resend.txt"
TELEMETRY_TEMP_RESEND_FILE="/opt/.temp_resend.txt"
TEMP_RESEND_FILE="/tmp/.resend.txt"
TELEMETRY_PROFILE_DEFAULT_PATH="/tmp/DCMSettings.conf"
TELEMETRY_PROFILE_RESEND_PATH="/opt/.DCMSettings.conf"
TEMP_LOG="/tmp/logs/messages.txt"

DEFAULT_IP="<#=#>ESTB_IP<#=#>"

MAX_LIMIT_RESEND=5
CURL_TIMEOUT=30
TLS=""
if [ -f /etc/os-release ]; then
    TLS="--tlsv1.2"
fi
TLSRet=""
MAX_UPLOAD_ATTEMPTS=3
RETRY_DELAY=60

dcaLog() {
    echo "`/bin/timestamp`: $0: $*" >> $RTL_LOG_FILE
}

tlsLog() { 
    echo "`/bin/timestamp`: $0: $*" >> $TLS_LOG_FILE
}

if [ $# -ne 2 ]; then
   dcaLog "Usage : `basename $0` <Trigger Type> sendInformation 0 or 1"
   dcaLog "Trigger Type : 1 (Upon log upload request)/ 0 (Count updating to file)"
   dcaLog "sendInformation : 1 (Will upload telemetry information)/ 0 (Will NOT upload telemetry information)"
   exit 0
fi

if [ -z $sleep_time ];then
    sleep_time=10
fi
dcaLog "sleep_time = $sleep_time"


if [ "$sendInformation" != "1" ]; then
   TELEMETRY_PROFILE_PATH=$TELEMETRY_PROFILE_RESEND_PATH
else
   TELEMETRY_PROFILE_PATH=$TELEMETRY_PROFILE_DEFAULT_PATH
fi
	
dcaLog "Telemetry Profile File Being Used : $TELEMETRY_PROFILE_PATH"

previousLogPath=""
TELEMETRY_PREVIOUS_LOG="/tmp/.telemetry_previous_log"
if [ -f $TELEMETRY_PREVIOUS_LOG ]; then
      previousLogPath="$LOG_PATH/PreviousLogs/"
      dcaLog "Telemetry run for previous log path : $previousLogPath $SORTED_PATTERN_CONF_FILE"
fi

if [ "${BUILD_TYPE}" = "dev" ]; then
    UPLOAD_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.DcaUploadUrl 2>&1)
else
    UPLOAD_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.DcaUploadPRODUrl 2>&1)
fi

if [ ! -z $UPLOAD_URL ]; then
    DCA_UPLOAD_URL=$UPLOAD_URL
fi

#Adding support for opt override for dcm.properties file
if [ "$BUILD_TYPE" != "prod" ] && [ -f /opt/dcm.properties ]; then
      . /opt/dcm.properties
else
      . /etc/dcm.properties
fi

if [ -f /tmp/.dcm_success ]; then
    dcaLog "Removing Telemetry directory $TELEMETRY_PATH"
    rm -rf $TELEMETRY_PATH     
    rm /tmp/.dcm_success
fi

if [ -f $RDK_PATH/mtlsUtils.sh ]; then
    . $RDK_PATH/mtlsUtils.sh
fi

#get telemetry opt out status
getOptOutStatus()
{
    optoutStatus=0
    currentVal="false"
    #check if feature is enabled through rfc
    rfcStatus=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.TelemetryOptOut.Enable 2>&1 > /dev/null)
    #check the current option
    if [ -f /opt/tmtryoptout ]; then
        currentVal=$(cat /opt/tmtryoptout)
    fi
    if [ "x$rfcStatus" == "xtrue" ]; then
        if [ "x$currentVal" == "xtrue" ]; then
            optoutStatus=1
        fi
    fi
    return $optoutStatus
}

#Obfuscate MAC address
ObfuscateMAC()
{
    ofcmac=""
    if [ -f /usr/bin/rdkssacli ]; then
        #GDPR_LOCALE defined in device.properties
        /usr/bin/rdkssacli "{PRIVACY=APPLY,POLICY=DEFAULT,LOCALE=$GDPR_LOCALE,SRC=TELEMETRY,DST=ANY,ITEM=MAC,VALUE=`/usr/bin/rdkssacli \"{IDENT=BASEMACADDRESS}\"`}" > /tmp/ofcmac
        if [ -f /tmp/ofcmac ]; then
            ofcmac=$(cat /tmp/ofcmac)
            rm -rf /tmp/ofcmac
        fi
    fi
    echo "$ofcmac"
}

TelemetryNewEndpointAvailable=0
getTelemetryEndpoint() {
    DEFAULT_DCA_UPLOAD_URL="$DCA_UPLOAD_URL"
    TelemetryEndpointURL=""
    TelemetryEndpoint=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.TelemetryEndpoint.Enable 2>&1 > /dev/null`
    if [ "x$TelemetryEndpoint" = "xtrue" ]; then
        TelemetryEndpointURL=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.TelemetryEndpoint.URL 2>&1 > /dev/null`
        if [ ! -z "$TelemetryEndpointURL" ]; then
            DCA_UPLOAD_URL="https://$TelemetryEndpointURL"
            dcaLog "dca upload url from RFC is $TelemetryEndpointURL"
            TelemetryNewEndpointAvailable=1
        fi
    else
        if [ -f "$TELEMETRY_PROFILE_DEFAULT_PATH" ]; then    
            TelemetryEndpointURL=`grep '"uploadRepository:URL":"' $TELEMETRY_PROFILE_DEFAULT_PATH | awk -F 'uploadRepository:URL":' '{print $NF}' | awk -F '",' '{print $1}' | sed 's/"//g' | sed 's/}//g'`
        fi
        
        if [ ! -z "$TelemetryEndpointURL" ]; then
            DCA_UPLOAD_URL=`echo "$TelemetryEndpointURL" | sed "s/http:/https:/g"`
            dcaLog "dca upload url from dcmresponse is $TelemetryEndpointURL"
        fi
    fi
    if [ -z "$TelemetryEndpointURL" ]; then
        DCA_UPLOAD_URL="$DEFAULT_DCA_UPLOAD_URL"
    fi
}

getTelemetryEndpoint

dcaLog "dca upload url : $DCA_UPLOAD_URL"

PrevFileName=''

if [ ! -d "$TELEMETRY_PATH_TEMP" ]
then
    dcaLog "Telemetry Folder does not exist . Creating now"
    mkdir -p "$TELEMETRY_PATH_TEMP"
else
    dcaLog "Telemetry Folder exists"
fi
 
cd $LOG_PATH

triggerType=1
TotalTuneCount=0
TuneFailureCount=0

isNum()
{
    Number=$1
    if [ $Number -ne 0 -o $Number -eq 0 2>/dev/null ];then
        echo 0
    else
        echo 1
    fi
}

getSNMPUpdates() {
     snmpMIB=$1
     TotalCount=0
     export MIBS=ALL
     export MIBDIRS=/mnt/nfs/bin/target-snmp/share/snmp/mibs:/usr/share/snmp/mibs
     export PATH=$PATH:/mnt/nfs/bin/target-snmp/bin
     export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
     snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
     tuneString=`snmpwalk  -OQv -v 2c -c $snmpCommunityVal 127.0.0.1 $snmpMIB`
     for count in $tuneString
     do
         count=`echo $count | tr -d ' '`
         if [ $(isNum $count) -eq 0 ]; then
            TotalCount=`expr $TotalCount + $count`
         else
            TotalCount=$count
         fi
     done
     
     echo $TotalCount
}

getControllerId(){    
    ChannelMapId=''
    ControllerId=''
    VctId=''
    vodServerId=''
    export MIBS=ALL
    export MIBDIRS=/mnt/nfs/bin/target-snmp/share/snmp/mibs:/usr/share/snmp/mibs
    export PATH=$PATH:/mnt/nfs/bin/target-snmp/bin
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
    
    snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
    ChannelMapId=`snmpwalk -OQv -v 2c -c $snmpCommunityVal 127.0.0.1 1.3.6.1.4.1.17270.9225.1.1.40`
    ControllerId=`snmpwalk -OQv -v 2c -c $snmpCommunityVal 127.0.0.1 1.3.6.1.4.1.17270.9225.1.1.41`  
    VctId=`snmpwalk -OQv -v 2c -c $snmpCommunityVal 127.0.0.1 OC-STB-HOST-MIB::ocStbHostCardVctId.0`
    vodServerId=`snmpwalk -OQv -v 2c -c $snmpCommunityVal 127.0.0.1 1.3.6.1.4.1.17270.9225.1.1.43`
    
    echo "{\"ChannelMapId\":\"$ChannelMapId\"},{\"ControllerId\":\"$ControllerId\"},{\"VctId\":$VctId},{\"vodServerId\":\"$vodServerId\"}"    
}

getControllerIdClient(){

   ChannelMapId=''
   ControllerId=''
   vodServerId=''

  
    ChannelMapId=`curl -d '{"paramList" : [{"name" : "Device.X_COMCAST-COM_Xcalibur.Client.XRE.xreChannelMapId"}]}' http://127.0.0.1:10999   | cut -d ":" -f4 | cut -d "\"" -f2`
    ControllerId=`curl -d '{"paramList" : [{"name" : "Device.X_COMCAST-COM_Xcalibur.Client.XRE.xreControllerId"}]}' http://127.0.0.1:10999   | cut -d ":" -f4 | cut -d "\"" -f2`
    vodServerId=`curl -d '{"paramList" : [{"name" : "Device.X_COMCAST-COM_Xcalibur.Client.XRE.xreVodId"}]}' http://127.0.0.1:10999 | cut -d ":" -f4 | cut -d "\"" -f2`
    echo "{\"ChannelMapId\":\"$ChannelMapId\"},{\"ControllerId\":\"$ControllerId\"},{\"vodServerId\":\"$vodServerId\"}"
} 

# Function to get RF status
getRFStatus(){
    Dwn_RX_pwr=''
    Ux_TX_pwr=''
    Dx_SNR=''
    export MIBS=ALL
    export MIBDIRS=/mnt/nfs/bin/target-snmp/share/snmp/mibs:/usr/share/snmp/mibs
    export PATH=$PATH:/mnt/nfs/bin/target-snmp/bin
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
    
    snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
    Dwn_RX_pwr=`snmpwalk -OQv -v 2c -c $snmpCommunityVal 192.168.100.1 DOCS-IF-MIB::docsIfDownChannelPower.3`
    Ux_TX_pwr=`snmpwalk -OQv -v 2c -c $snmpCommunityVal 192.168.100.1 DOCS-IF-MIB::docsIfCmStatusTxPower.2`  
    Dx_SNR=`snmpwalk -OQv -v 2c -c $snmpCommunityVal 192.168.100.1 DOCS-IF-MIB::docsIfSigQSignalNoise.3`
    
    echo "{\"Dwn_RX_pwr\":\"$Dwn_RX_pwr\"},{\"Ux_TX_pwr\":\"$Ux_TX_pwr\"},{\"Dx_SNR\":\"$Dx_SNR\"}"
}

# Function to get Offline status 
getOfflineStatus() {
    offline_status=''
    cablecard=''
    filePath=""
    if [ -f $TELEMETRY_PATH/lastlog_path ]; then
        filePath=`cat $TELEMETRY_PATH/lastlog_path`
    fi
    dcaLog "File Path = $filePath"
    offline_status=`nice -20 grep 'CM  STATUS :' $filePath/ocapri_log.txt | tail -1`
    dcaLog "Last Cable Card Status = $offline_status"
    operational_check=`echo $offline_status | grep -c "Operational"`
    if [ $operational_check -eq 0 ]; then
        cablecard=`echo $offline_status | awk -F ': ' '{print $NF}'`
    fi
    
    rm -f $TELEMETRY_PATH/lastlog_path
    
    if [ -n "$cablecard" ]; then
        echo "{\"Cable_Card\":\"$cablecard\"}"
    fi
}
    
# Function to get current image version 
getFWVersion()
{
   verStr=`cat /version.txt | grep ^imagename:$FW_VERSION_TAG1`
   if [ $? -eq 0 ]
   then
       echo $verStr | cut -d ":" -f 2
   else
       cat /version.txt | grep ^imagename:$FW_VERSION_TAG2 | cut -d ":" -f 2
   fi
}

clearTelemetryConfig()
{
    if [ -f $MAP_PATTERN_CONF_FILE ]; then
        dcaLog "MAP_PATTERN_CONF_FILE : $MAP_PATTERN_CONF_FILE"
        rm -f $MAP_PATTERN_CONF_FILE
    fi

    if [ -d $TELEMETRY_PATH_TEMP ]; then
        rm -rf $TELEMETRY_PATH_TEMP
        mkdir -p $TELEMETRY_PATH_TEMP
    fi
    
    dcaLog "TEMP_PATTERN_CONF_FILE : $TEMP_PATTERN_CONF_FILE"
    echo "" > $TEMP_PATTERN_CONF_FILE
        
}

generateTelemetryConfig()
{
    if [ -f $TELEMETRY_PROFILE_PATH ]; then
        grep -i 'TelemetryProfile' $TELEMETRY_PROFILE_PATH | sed 's/=\[/\n/g' | sed 's/},/}\n/g' | sed 's/],.*?/\n/g'| sed -e 's/^[ ]//' > $TEMP_PATTERN_CONF_FILE
    fi

    #Create map file from json message file
    while read line
    do         
        header_Check=`echo "$line" | grep -c '{"header"'`
        if [ $header_Check -ne 0 ];then
            polling=`echo "$line" | grep -c 'pollingFrequency'`
            # Requirement of RDKALL-76 - Reusing pollingFrequency as skip interval to avoid server side changes
            if [ $polling -ne 0 ];then
                header=`echo "$line" | awk -F '"header" :' '{print $NF}' | awk -F '",' '{print $1}' | sed -e 's/^[ ]//' | sed 's/^"//'`
                content=`echo "$line" | awk -F '"content" :' '{print $NF}' | awk -F '",' '{print $1}' | sed -e 's/^[ ]//' | sed 's/^"//'`
                logFileName=`echo "$line" | awk -F '"type" :' '{print $NF}' | awk -F '",' '{print $1}' | sed -e 's/^[ ]//' | sed 's/^"//'`
                skipInterval=`echo "$line" | sed -e "s/.*pollingFrequency\":\"//g" | sed 's/"}//'`
            else
                #header=`echo "$line" | cut -d ':' -f2- | awk -F '",' '{print $1}' | sed -e 's/^[ ]//' | sed 's/^"//'`
                header=`echo "$line" | awk -F '"header" :' '{print $NF}' | awk -F '",' '{print $1}' | sed -e 's/^[ ]//' | sed 's/^"//'`
                content=`echo "$line" | awk -F '"content" :' '{print $NF}' | awk -F '",' '{print $1}' | sed -e 's/^[ ]//' | sed 's/^"//'`
                logFileName=`echo "$line" | awk -F '"type" :' '{print $NF}' | sed -e 's/^[ ]//' | sed 's/^"//' | sed 's/"}//'`
                #default value to 0
                skipInterval=0
            fi 

            if [ -n "$header" ] && [ -n "$content" ] && [ -n "$logFileName" ] && [ -n "$skipInterval" ]; then
                echo "$header<#=#>$content<#=#>$logFileName<#=#>$skipInterval" >> $MAP_PATTERN_CONF_FILE
            fi
        fi
    
    done < $TEMP_PATTERN_CONF_FILE

    if [ -f $MAP_PATTERN_CONF_FILE ]; then
        awk -F '<#=#>' '{print $3,$0}' $MAP_PATTERN_CONF_FILE | sort -n | cut -d ' ' -f 2- > $SORTED_PATTERN_CONF_FILE #Sort the conf file with the the filename
    fi

}

sendDirectTelemetryRequest()
{
    EnableOCSPStapling="/tmp/.EnableOCSPStapling"
    EnableOCSP="/tmp/.EnableOCSPCA"

    dcaLog "dca$2: Attempting $TLS direct connection to telemetry service"
    dcaLog "Log Upload requires Mutual Authentication"
    if [ "$LONG_TERM_CERT" == "true" ]; then
        cert=`getMtlsCreds dca_utility.sh /etc/ssl/certs/dcm-cpe-clnt.xcal.tv.cert.pem /tmp/geyoxnweddys`
    else
        cert=`getMtlsCreds dca_utility.sh`
    fi
    dcaLog "MTLS creds for Log Upload fetched"
    if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
        CURL_CMD="curl $TLS$cert -w '%{http_code}\n' -H \"Accept: application/json\" -H \"Content-type: application/json\" -X POST -d '$1' -o \"$HTTP_FILENAME\" \"$DCA_UPLOAD_URL\" --cert-status --connect-timeout $CURL_TIMEOUT -m $CURL_TIMEOUT"
        HTTP_CODE=`curl $TLS$cert -w '%{http_code}\n' -H "Accept: application/json" -H "Content-type: application/json" -X POST -d  "$1" -o "$HTTP_FILENAME" "$DCA_UPLOAD_URL" --cert-status --connect-timeout $CURL_TIMEOUT -m $CURL_TIMEOUT`
        TLSRet=$?
    elif [ "$mTLS_RPI" == "true" ] ; then
        dcaLog " RPI_DCA_CURL_IN_PROGRESS"
        CURL_CMD="curl --cert-type pem --key /tmp/xconf-file.tmp --cert /etc/ssl/certs/refplat-xconf-cpe-clnt.xcal.tv.cert.pem -w '%{http_code}\n' -H \"Accept: application/json\" -H \"Content-type: application/json\" -X POST -d '$1' -o \"$HTTP_FILENAME\" \"$DCA_UPLOAD_URL\" --connect-timeout $CURL_TIMEOUT -m $CURL_TIMEOUT"
        HTTP_CODE=`curl --cert-type pem --key /tmp/xconf-file.tmp --cert /etc/ssl/certs/refplat-xconf-cpe-clnt.xcal.tv.cert.pem  -w '%{http_code}\n' -H "Accept: application/json" -H "Content-type: application/json" -X POST -d  "$1" -o "$HTTP_FILENAME" "$DCA_UPLOAD_URL" --connect-timeout $CURL_TIMEOUT -m $CURL_TIMEOUT`
    else
        CURL_CMD="curl $TLS$cert -w '%{http_code}\n' -H \"Accept: application/json\" -H \"Content-type: application/json\" -X POST -d '$1' -o \"$HTTP_FILENAME\" \"$DCA_UPLOAD_URL\" --connect-timeout $CURL_TIMEOUT -m $CURL_TIMEOUT"
        HTTP_CODE=`curl $TLS$cert -w '%{http_code}\n' -H "Accept: application/json" -H "Content-type: application/json" -X POST -d  "$1" -o "$HTTP_FILENAME" "$DCA_UPLOAD_URL" --connect-timeout $CURL_TIMEOUT -m $CURL_TIMEOUT`
        TLSRet=$?
    fi
 
    dcaLog "dca$2: CURL_CMD: `echo "$CURL_CMD" | sed -e 's#devicecert_1.*-w#devicecert_1.pk12<masked> -w#g' | sed -e 's#staticXpkiCrt.*-w#staticXpkiCrt.pk12<masked> -w#g'`"

    case $TLSRet in
        35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
            tlsLog "dca$2: HTTPS $TLS failed to connect to telemetry service with curl error code $TLSRet"
	    ;;
    esac
    dcaLog  "Curl return code : $TLSRet"
    rm -rf $ID
    return $TLSRet
}

uploadTelemetryData()
{
    http_code="000"
    retries=0

    dcaLog "uploadTelemetryData:  Telemetry endpoint is always direct connect"
    while [ $retries -lt $MAX_UPLOAD_ATTEMPTS ]
    do
        # Use direct connection alway
        sendDirectTelemetryRequest "$1" "$2"
        ret=$TLSRet
        http_code=$(echo "$HTTP_CODE" | awk -F\" '{print $1}' )
        if [ "$http_code" = "200" ]; then
            dcaLog "uploadTelemetryData: Telemetry data upload success dca$2: HTTP RESPONSE CODE : $http_code"
            break
        elif [ "$http_code" = "404" ]; then
            dcaLog "uploadTelemetryData: Received 404 response for Telemetry data upload, Retry logic not needed"
            break
        fi
        dcaLog "uploadTelemetryData: Telemetry data upload return dca$2: RETRIES:$retries RET: $ret HTTP RESPONSE CODE : $http_code"
        retries=`expr $retries + 1`
        sleep $RETRY_DELAY
    done

    if [ "$http_code" = "000" ]; then
        dcaLog "uploadTelemetryData: Telemetry data upload Direct connection failed with RET: $ret HTTP RESPONSE CODE : $http_code"
        dcaLog "uploadTelemetryData: Telemetry data upload CodeBig connection not supported"
    elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
        dcaLog "uploadTelemetryData: Telemetry data upload dca$2 failed with RET: $ret HTTP RESPONSE CODE : $http_code"
    fi
}

#main app
if [ ! -f $SORTED_PATTERN_CONF_FILE ]; then
   if [ -f $TELEMETRY_RESEND_FILE -a "`wc -l $TELEMETRY_RESEND_FILE | cut -d ' ' -f 1`" -ge "$MAX_LIMIT_RESEND" ]; then
      dcaLog "resend queue size at its max. removing recent two entries"
      sed -i '$d' $TELEMETRY_RESEND_FILE
      sed -i '$d' $TELEMETRY_RESEND_FILE
   fi
   clearTelemetryConfig
   generateTelemetryConfig 
fi

if [ -f $MAP_PATTERN_CONF_FILE ]; then
    KILL_SWITCH="/opt/stop_xi_recovery"
    disableFaultyClient=`grep -i 'CheckXiRecoveryDisable' $MAP_PATTERN_CONF_FILE`
    if [ ! -z "$disableFaultyClient" ]; then
        touch $KILL_SWITCH
    else
        rm -f $KILL_SWITCH
    fi
fi

if [ -f $RTL_TEMP_LOG_FILE ]; then
    dcaLog "Deleting : $RTL_TEMP_LOG_FILE"
    rm -f $RTL_TEMP_LOG_FILE
fi

# Search for all patterns and file from conf file
if [ -f $SORTED_PATTERN_CONF_FILE ]; then
    defaultOutputJSON="{\"searchResult\":[{\"<remaining_keys>\":\"<remaining_values>\"}]}"
    dcaOutputJson=`nice -n 19 $DCA_BINARY $SORTED_PATTERN_CONF_FILE $previousLogPath 2>> $RTL_LOG_FILE`
    if [ -z "$dcaOutputJson" ];
    then
      dcaOutputJson=$defaultOutputJSON
    fi
    singleEntry=true

    if [ "$DEVICE_TYPE" != "mediaclient" ];
    then
      while read line
      do
          header=`echo "$line" | awk -F '<#=#>' '{print $1}'`
          pattern=`echo "$line" | awk -F '<#=#>' '{print $2}'`
          filename=`echo "$line" | awk -F '<#=#>' '{print $3}'`
          if [ ! -z "$filename" ] && [ "$filename" == "snmp" ] || [ "$filename" == "SNMP" ]; then
              retvalue=$(getSNMPUpdates $pattern)
              if $singleEntry ; then
                 tuneData="{\"$header\":\"$retvalue\"}"
                 outputJsonSuffix="$outputJsonSuffix$tuneData"
                 singleEntry=false
              else
                 tuneData=",{\"$header\":\"$retvalue\"}"
                 outputJsonSuffix="$outputJsonSuffix$tuneData" 
              fi                
          fi
      done < $SORTED_PATTERN_CONF_FILE
    fi
    
    # Form the json message from the updated count file 
    if [ $triggerType -eq 1 ]; then
       if [ -n "$outputJsonSuffix" ]; then
          if $singleEntry ; then
              outputJson="$outputJson$outputJsonSuffix"
              singleEntry=false
          else
              outputJson="$outputJson,$outputJsonSuffix"
          fi
       fi

       estbMac=`getEstbMacAddress`
       estbIp=`getIPAddress`
       receiverId=$(getReceiverId)
       partnerId=$(getPartnerId)
       accountId=$(getAccountId)
       experience=$(getExperience)
       firmwareVersion=$(getFWVersion)
       cur_time=`date "+%Y-%m-%d %H:%M:%S"`

       getOptOutStatus
       opt_out=$?
       if [ $opt_out -eq 1 ]; then
          dcaLog "TelemetryOptOut is true"
          estbMac=$(ObfuscateMAC)
          dcaLog "Obfuscated MAC is $estbMac"
       fi

       if [ "$estbIp" = "" -a "$sendInformation" != "1" ]; then
           estbIp="$DEFAULT_IP"
       fi
	   
        if [ -f $TELEMETRY_PATH/lastlog_path ];
        then            
            dcaLog "File $TELEMETRY_PATH/lastlog_path exists."
            offline_status=$(getOfflineStatus)
            if [ -n "$offline_status" ]; then
                if $singleEntry ; then
                  outputJson="$outputJson$offline_status"
                  singleEntry=false
                else
                  outputJson="$outputJson,$offline_status" 
                fi
            fi
            if [ "$DEVICE_TYPE" != "mediaclient" ];
            then
                cntrl_id=$(getControllerId)
            else
                cntrl_id=$(getControllerIdClient)
            fi    
            if [ -n "$cntrl_id" ]; then
               if $singleEntry ; then
                   outputJson="$outputJson$cntrl_id"
                   singleEntry=false
               else
                   outputJson="$outputJson,$cntrl_id"                 
               fi
            fi
            
            if [ "$DEVICE_TYPE" != "mediaclient" ];
            then
              rfstatus=$(getRFStatus)
              if [ -n "$rfstatus" ]; then
                 if $singleEntry ; then
                     outputJson="$outputJson$rfstatus"
                     singleEntry=false
                 else
                     outputJson="$outputJson,$rfstatus"                 
                 fi            
              fi
            fi
           rm -f $TELEMETRY_PATH/lastlog_path 
        else
            dcaLog "File $TELEMETRY_PATH/lastlog_path  does not exist. Not sending Cable Card Informtion " 
        fi		
   
        # Getting ping telemetry data if any and appending to the telemetry JSON 
        if [ -f /etc/os-release ]; then
            sh /lib/rdk/ping-telemetry-data.sh >> $RTL_LOG_FILE
            if [ -f /opt/pingData ]; then
                pingdata=`cat /opt/pingData`
                rm /opt/pingData
                if [ "$pingdata" != "" ]; then
                    if $singleEntry ; then
                        outputJson="$outputJson$pingdata"
                        singleEntry=false
                    else
                        outputJson="$outputJson,$pingdata"
                    fi
                fi
            fi
        fi

 
        if $singleEntry ; then
            outputJson="$outputJson{\"Profile\":\"RDKV\"},{\"mac\":\"$estbMac\"},{\"StbIp\":\"$estbIp\"},{\"receiverId\":\"$receiverId\"},{\"PartnerId\":\"$partnerId\"},{\"AccountId\":\"$accountId\"},{\"Experience\":\"$experience\"},{\"Version\":\"$firmwareVersion\"},{\"Time\":\"$cur_time\"}"
            singleEntry=false
        else
            outputJson="$outputJson,{\"Profile\":\"RDKV\"},{\"mac\":\"$estbMac\"},{\"StbIp\":\"$estbIp\"},{\"receiverId\":\"$receiverId\"},{\"PartnerId\":\"$partnerId\"},{\"AccountId\":\"$accountId\"},{\"Experience\":\"$experience\"},{\"Version\":\"$firmwareVersion\"},{\"Time\":\"$cur_time\"}"
        fi

        if [ -f $TELEMETRY_PREVIOUS_LOG ]; then
            outputJson="{\"PREVIOUS_LOG\":\"1\"},$outputJson"
        fi

        if [ -f $RTL_TEMP_LOG_FILE ]; then
            rm -f $RTL_TEMP_LOG_FILE
        fi
        dcaLog "DCA processing complete, clearing up $RTL_TEMP_LOG_FILE"

        remain="{\"<remaining_keys>\":\"<remaining_values>\"}"
        outputJson=`echo "$dcaOutputJson" | sed "s/$remain/$outputJson/"`
        
        echo $outputJson >> $RTL_LOG_FILE
        
        if [ "$sendInformation" != "1" ]; then
            if [ -f $TELEMETRY_RESEND_FILE -a "`wc -l $TELEMETRY_RESEND_FILE | cut -d ' ' -f 1`" -ge "$MAX_LIMIT_RESEND" ]; then
                dcaLog "resend queue size has already reached MAX_LIMIT_RESEND. Not adding anymore entries"
            else
                if [ -f $TELEMETRY_TEMP_RESEND_FILE ]; then
                        previousReport=`cat $TELEMETRY_TEMP_RESEND_FILE`
                        dcaLog "Previous report is avilable append to resend file"
                        echo $previousReport >> $RTL_LOG_FILE
                        echo $previousReport >> $TELEMETRY_RESEND_FILE
                        rm -f $TELEMETRY_TEMP_RESEND_FILE
                fi
                echo $outputJson >> $TELEMETRY_RESEND_FILE
                dcaLog "resend : Storing data to resend"
                if [ "$flag" = "1" ]; then
                    kill `ps h -o pid -C dca_utility.sh`
                    dcaLog "Exiting dca_utility."
                    exit 0
                fi
                if [ "$sendInformation" = "2" ]; then
                    dcaLog "Exiting dca_utlity.Deep sleep triggered"
                    exit 0
                fi

            fi
        else
           echo $outputJson > $TELEMETRY_TEMP_RESEND_FILE
	   dcaLog "sleeping $sleep_time seconds"
           sleep $sleep_time
           retry=0
           rm -f $TELEMETRY_TEMP_RESEND_FILE
           
           if [ -f $TELEMETRY_RESEND_FILE ]; then
               rm -f $TELEMETRY_TEMP_RESEND_FILE
               sed -r 's#\\#\\\\#g' $TELEMETRY_RESEND_FILE > $TEMP_RESEND_FILE
	       while read resend
	       do
                   resend=`echo $resend | sed "s/$DEFAULT_IP/$estbIp/"`
                   uploadTelemetryData "$resend" " resend"
                   ret=$TLSRet
                   http_code=$(echo "$HTTP_CODE" | awk -F\" '{print $1}' )

                   if [ "$http_code" != "200" ]; then
                       if [ "$retry" -le "$MAX_LIMIT_RESEND" ]; then
                          # Store this line from resend file to a temp resend file
                          # This is to address the use case when device is offline
                          echo "$resend" >> $TELEMETRY_TEMP_RESEND_FILE
                       else
                          dcaLog "resend queue size has already reached MAX_LIMIT_RESEND. Not adding anymore entries"
                       fi
                   fi
                   retry=$((retry + 1))
               done < $TEMP_RESEND_FILE
               rm -f $TEMP_RESEND_FILE
               rm -f $TELEMETRY_RESEND_FILE

               if [ -f $TELEMETRY_TEMP_RESEND_FILE ]; then
                   mv $TELEMETRY_TEMP_RESEND_FILE $TELEMETRY_RESEND_FILE
               fi
           fi

           uploadTelemetryData "$outputJson"
           ret=$TLSRet
           http_code=$(echo "$HTTP_CODE" | awk -F\" '{print $1}' )
    
           if [ "$http_code" = "200" ];then
              dcaLog "Json message successfully submitted. Moving files from $TELEMETRY_PATH_TEMP to $TELEMETRY_PATH"
           else
              dcaLog "Json message submit failed. Removing files from $TELEMETRY_PATH_TEMP"
              if [ -f $TELEMETRY_RESEND_FILE -a "`wc -l $TELEMETRY_RESEND_FILE | cut -d ' ' -f 1`" -ge "$MAX_LIMIT_RESEND" ]; then
                 dcaLog "resend queue size has already reached MAX_LIMIT_RESEND. Not adding anymore entries"
              else
                 touch $TELEMETRY_RESEND_FILE
                 echo "$outputJson" >> $TELEMETRY_RESEND_FILE
              fi
           fi
           if [ ! -f $TELEMETRY_PREVIOUS_LOG ]; then
               if [ -f $EXEC_COUNTER_FILE ]; then
                   dcaNexecCounter=`cat $EXEC_COUNTER_FILE`
                   dcaNexecCounter=`expr $dcaNexecCounter + 1`
               else
                   dcaNexecCounter=0;
               fi
               echo "$dcaNexecCounter" > $EXEC_COUNTER_FILE
           fi
        fi
    fi
else
    dcaLog "Configuration File Not Found"
fi

# Safe clean up during exit 
if [ -f $RTL_TEMP_LOG_FILE ]; then
    rm -f $RTL_TEMP_LOG_FILE
fi

if [ -f $TEMP_PATTERN_CONF_FILE ]; then
    rm -f $TEMP_PATTERN_CONF_FILE
fi

if [ -f $TELEMETRY_PREVIOUS_LOG ]; then
    rm -rf $TELEMETRY_PREVIOUS_LOG
fi

exit 0

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

if [ "$DEVICE_TYPE" != "mediaclient" ]; then
     . /lib/rdk/commonUtils.sh
fi

export PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/sbin:/usr/local/lighttpd/sbin:/usr/local/sbin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/Qt/lib:/usr/local/lib

LOG_FILE="/opt/logs/discoverV4Client.log"
CONNECTED_XG_DEVICE_LIST='/tmp/.connectedXG'
CONNECTED_DEVICE_LIST='/tmp/.connectedMocaDevices'
TMP_CONNECTED_DEVICE_LIST='/tmp/.tmpConnectedMocaDevices'

EXECUTION_LOCK="/tmp/.discoverClientInProgress"
CLIENT_CLEAN_LIST="/opt/.clientCleanList.txt"
MOCA_V6_CLIENT_FILE="/tmp/.mocaV6client"
KILL_SWITCH="/opt/stop_xi_recovery"

SPLUNK_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.DcaUploadUrl 2>&1)
if [ -z $SPLUNK_URL ]; then
    . /etc/dcm.properties
    SPLUNK_URL=$DCA_UPLOAD_URL
fi

HTTP_FILENAME='/tmp/.xiDiscResponse.txt'
HTTP_CODE="/tmp/.xiDiscHttpcode"

upnpDataFile=""

EnableOCSPStapling="/tmp/.EnableOCSPStapling"
EnableOCSP="/tmp/.EnableOCSPCA"

logMessage() {
    if [ -f /tmp/.standby ]; then
        LOG_FILE="/tmp/discoverV4Client.log"
    fi
    echo "`date +%Y-%m-%d-%H-%M-%S` $1" >> $LOG_FILE
}

# Convert Ipv6 Address to full zero padded address format
getStandardV6AddrFormat() {
    IPv6_RAW_ADDR=$1
    IPv6_RAW_ADDR=`echo $IPv6_RAW_ADDR | sed -e 's/::/:0:/g' -e 's/:/ /g'`
    tempIpv6Addr=""
    for unpaddedAddr in $IPv6_RAW_ADDR
    do
        zeroPaddedAddr=`printf "%04x" 0x${unpaddedAddr}`
        tempIpv6Addr=$tempIpv6Addr$zeroPaddedAddr
    done

    IPv6_RAW_ADDR=`echo $tempIpv6Addr | sed 's/..../&:/g'`
    echo "${IPv6_RAW_ADDR%:*}"
}

updateDeviceCleanList() {
   clientMac=$1
   if [ -f $CLIENT_CLEAN_LIST ]; then
       grep -iq "$clientMac" $CLIENT_CLEAN_LIST
       if [ $? -ne 0 ]; then
           echo "$clientMac" >> $CLIENT_CLEAN_LIST
       fi
   else
       echo "$clientMac" >> $CLIENT_CLEAN_LIST
   fi
}

checkDeviceInCleanList() {
   clientMac=$1
   grep -iq "$clientMac" $CLIENT_CLEAN_LIST
   if [ $? -eq 0 ]; then
       logMessage "$clientMac is in clean device list"
       return 0
   else 
       logMessage "$clientMac is not in clean device list"
       return 1
   fi
}

genMocaV6ClientList() {
   rm -f $MOCA_V6_CLIENT_FILE
   ip -6 neigh show | grep ${MOCA_INTERFACE} | grep -i 'REACHABLE' | cut -d ' ' -f1 > /tmp/.v6ArpList
   # Update address to a common format to avoid false failures
   while read LINE
   do
       v6Addr=`getStandardV6AddrFormat "$LINE"`
       if [ ! -z "$v6Addr" ]; then
           echo "$v6Addr" >> $MOCA_V6_CLIENT_FILE
       fi
   done < /tmp/.v6ArpList
   rm -f /tmp/.v6ArpList
}

isInMocaV6ClientList() {
   clientAddr=$1
   if [ ! -f $MOCA_V6_CLIENT_FILE ]; then
       return 1
   fi
   grep -iq "$clientAddr" ${MOCA_V6_CLIENT_FILE}
   if [ $? -eq 0 ]; then
       logMessage "$clientAddr is in MoCA v6 neighbour list"
       return 0
   else 
       logMessage "$clientAddr is not in MoCA v6 neighbour list"
       return 1
   fi

}

if [ -f $KILL_SWITCH ]; then
    logMessage "Kill switch enabled. Exiting from IPv6 client validation logic !!!"
    exit 0
fi

# If trigger is path based activation from UPNP ignore file deletion activation
if [ "x$1" == "xupnp" ] && [ ! -f /tmp/upnp_client_ipaddr.txt ]; then
    exit 0
fi

while [ ! -f /tmp/estb_ipv6 ]
do
   sleep 5
   if [ -f /tmp/estb_ipv4 ];then
     logMessage "Gateway is in IPv4 mode. Exiting faulty client detection !!!"
     exit 0
   fi
done

if [ -f $EXECUTION_LOCK ]; then
    logMessage "Previous instance of $0 is runnig. Exiting !!!"
    exit 0
fi

touch $EXECUTION_LOCK

# Clean up tmp files
rm -f $CONNECTED_DEVICE_LIST
rm -f $TMP_CONNECTED_DEVICE_LIST

# Get List of IPv4 Address Of Connected XGs And Xis with versions supporting fog
if [ -f /opt/output.json ] || [ -f /tmp/output.json ]; then
    if [ "$CPU_ARCH" == "x86" ]; then
        upnpDataFile="/tmp/output.json"
    else
        upnpDataFile="/opt/output.json"
    fi
    cat $upnpDataFile | grep "gatewayip" | grep -v 'gatewayipv6' > $CONNECTED_XG_DEVICE_LIST
    # Include XIs supporting fog to exlusion list.
    # Fog support is included only with 2.5 images
    grep 'fogTsbUrl' $upnpDataFile | sed -e "s|http.*://||g" -e "s|\"fogTsbUrl\":|\"gatewayip\"=|g" \
         | sed -e "s|:.*|\",|g" -e "s|=|:|g" | grep -v 'null' >> $CONNECTED_XG_DEVICE_LIST

else 
    logMessage "Unable to locate output.json file !!! Exiting..."
    rm -f $EXECUTION_LOCK
    exit 1
fi

# Get all connectd devices over MoCA interface
if [ "x$1" == "xupnp" ]; then
    # Ensure we are not using outdated arp cache
    ip neigh flush all
    sleep 5
    arp -a | grep $MOCA_INTERFACE | grep -v 'incomplete' | sed -e "s/(//g" -e "s/)//g" | cut -d ' ' -f2,4 > $TMP_CONNECTED_DEVICE_LIST
    
   # Consider only device list from upnp
   if [ ! -f /tmp/upnp_client_ipaddr.txt ]; then
       rm -f $EXECUTION_LOCK
       exit 0
   fi
   while read LINE
   do
       validEntry=`grep  "$LINE" $TMP_CONNECTED_DEVICE_LIST`
       if [ ! -z "$validEntry" ]; then
           echo "$validEntry" >> $CONNECTED_DEVICE_LIST
       fi
   done < /tmp/upnp_client_ipaddr.txt
else
    arp -a | grep $MOCA_INTERFACE | grep '169' | grep -v 'incomplete' | sed -e "s/(//g" -e "s/)//g" | cut -d ' ' -f2,4 > $CONNECTED_DEVICE_LIST
fi

if [ ! -f $CONNECTED_DEVICE_LIST ]; then
   logMessage "No connected devices in the MoCA network. Exiting validation !!!"
   rm -f $EXECUTION_LOCK
   exit 0
fi

# Remove XG's from the connected list which will give the XI device list
while read LINE
do
   ip=`echo $LINE | cut -d ':' -f2 | cut -d ':' -f2 | sed -e 's/"//g' -e 's/,//g'`
   sed -i "/$ip/d" $CONNECTED_DEVICE_LIST
done < $CONNECTED_XG_DEVICE_LIST

v6prefixfile=/tmp/dibbler/client-AddrMgr.xml
ipv6_prefix=`grep -F "AddrPrefix" $v6prefixfile | cut -d ">" -f2 | cut -d "<" -f1 `
while [ -z "$ipv6_prefix" ]
do
    sleep 10
    logMessage "Waiting for identifying the gateway prefix"
    ipv6_prefix=`grep -F "AddrPrefix" $v6prefixfile | cut -d ">" -f2 | cut -d "<" -f1 `
done

logMessage "Connected XI Clients : "
cat $CONNECTED_DEVICE_LIST >> $LOG_FILE


if [ "$CPU_ARCH" == "x86" ] && [ ! -f /etc/os-release ]; then
    logMessage "ipv6 neighbour data is not supported. Using ping6 to check validity"
else
    genMocaV6ClientList 
fi

tmpFaultyList="/tmp/.faultyXiList.txt"
touch $tmpFaultyList
# Generate possible IPv6 Address for client and check for connectivity
while read LINE
do
   clientIP=''
   clientMac=''
   GEN_IPV6ADDRESS=''
   GEN_IPV6ADDRESS2=''

   clientIP=`echo $LINE | cut -d ' ' -f1`
   clientMac=`echo $LINE | cut -d ' ' -f2 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}'`
   logMessage "clientIP : $clientIP     clientMac : $clientMac ipv6_prefix : $ipv6_prefix"
   if [ -f $CLIENT_CLEAN_LIST ]; then
       checkDeviceInCleanList "$clientMac"
       if [ $? -eq 0 ]; then
           #This client is in clean list, not alerting telemetry
           continue
       fi
   fi
   GEN_IPV6ADDRESS=`ipv6calc --in prefix+mac --action prefixmac2ipv6 --out ipv6addr "$ipv6_prefix" "$clientMac"`
   GEN_IPV6ADDRESS=`getStandardV6AddrFormat "$GEN_IPV6ADDRESS"`
   logMessage "MAC based IPv6 Address = $GEN_IPV6ADDRESS"
   if [ "$CPU_ARCH" == "x86" ] && [ ! -f /etc/os-release ]; then
       ping6 -c 1 -W 3 "$GEN_IPV6ADDRESS" > /dev/null
   else
       isInMocaV6ClientList "$GEN_IPV6ADDRESS" 
   fi
   if [ $? -eq 0 ]; then
      logMessage "v6 client $GEN_IPV6ADDRESS is reachable. Not a faulty client"
      updateDeviceCleanList "$clientMac"
      continue
   fi

   gwIf_IPv4=`printf '%02X' ${clientIP//./ }`
   hexFormatedLowerBits=`echo $gwIf_IPv4 | sed -e 's/..../&:/g' -e 's/:$//'`
   IPV6PREFIXLEFT=`echo $ipv6_prefix | awk -F/ '{print $1}'`
   logMessage "IPV6PREFIXLEFT=$IPV6PREFIXLEFT"
   #Replace lower two 64 bits with the one derived from IPv4 address
   GEN_IPV6ADDRESS2=${GEN_IPV6ADDRESS%:*}
   GEN_IPV6ADDRESS2=${GEN_IPV6ADDRESS2%:*}
   GEN_IPV6ADDRESS2="${GEN_IPV6ADDRESS2}:${hexFormatedLowerBits}"
   GEN_IPV6ADDRESS2=`getStandardV6AddrFormat "$GEN_IPV6ADDRESS2"`
   logMessage "IPv4 based IPv6 Address = $GEN_IPV6ADDRESS2"

   if [ "$CPU_ARCH" == "x86" ] && [ ! -f /etc/os-release ]; then
       ping6 -c 1 -W 3 "$GEN_IPV6ADDRESS2" > /dev/null
   else
       isInMocaV6ClientList "$GEN_IPV6ADDRESS2" 
   fi

   if [ $? -eq 0 ]; then
      logMessage "v6 client $GEN_IPV6ADDRESS2 is reachable. Not a faulty client"
      updateDeviceCleanList "$clientMac"
      continue
   fi
   # Add possible V6 Address, MAC and IPv4 to list
   echo "V6Addr1=$GEN_IPV6ADDRESS V6Addr2=$GEN_IPV6ADDRESS2 MAC=$clientMac V4Addr=$clientIP" >> $tmpFaultyList
done < $CONNECTED_DEVICE_LIST

# Wait for 30 sec and revalidate before splunk update
sleep 30

if [ "$CPU_ARCH" == "x86" ] && [ ! -f /etc/os-release ]; then
    logMessage "ipv6 neighbour data is not supported. Using ping6 to check validity"
else
    genMocaV6ClientList 
fi


singleEntry=true
outputJson=""
while read LINE
do
   # Add MAC + IP to splunk send list
   GEN_IPV6ADDRESS1=`echo $LINE | cut -d " " -f1 | cut -d "=" -f2`
   if [ "$CPU_ARCH" == "x86" ] && [ ! -f /etc/os-release ]; then
       ping6 -c 1 -W 3 "$GEN_IPV6ADDRESS1" > /dev/null
   else
       isInMocaV6ClientList "$GEN_IPV6ADDRESS1" 
   fi
   if [ $? -eq 0 ]; then
      logMessage "v6 client $GEN_IPV6ADDRESS1 is reachable. Not a faulty client"
      updateDeviceCleanList "$clientMac"
      continue
   fi
   GEN_IPV6ADDRESS2=`echo $LINE | cut -d " " -f2 | cut -d "=" -f2`
   if [ "$CPU_ARCH" == "x86" ] && [ ! -f /etc/os-release ]; then
       ping6 -c 1 -W 3 "$GEN_IPV6ADDRESS2" > /dev/null
   else
       isInMocaV6ClientList "$GEN_IPV6ADDRESS2" 
   fi
   if [ $? -eq 0 ]; then
      logMessage "v6 client $GEN_IPV6ADDRESS2 is reachable. Not a faulty client"
      updateDeviceCleanList "$clientMac"
      continue
   fi

   clientMac=`echo $LINE | cut -d " " -f3 | cut -d "=" -f2`
   clientIP=`echo $LINE | cut -d " " -f4 | cut -d "=" -f2`
   ## Random delay observed in device list getting updated in UPNP list.
   ## Final check to ensure this device IP is not in XG class device before alert
   if [ -f $upnpDataFile ]; then
       grep "gatewayip" $upnpDataFile  | grep -v 'gatewayipv6' | grep -iq "$clientIP"
       if [ $? -eq 0 ]; then
           logMessage "$clientIP present in $upnpDataFile. Not a faulty client."
           continue
       fi
   fi

   if $singleEntry ; then
       tempString="{\"macAddress\" : \"$clientMac\",\"ipv4address\":\"$clientIP\"}"
       singleEntry=false
   else
       tempString=",{\"macAddress\" : \"$clientMac\" , \"ipv4address\":\"$clientIP\"}"
   fi
   outputJson="$outputJson$tempString"
done < $tmpFaultyList

rm -f $tmpFaultyList

if [  ! -z "$outputJson" ]; then

    outputJson="{\"clientsList\": [$outputJson]}"
    cur_time=`date "+%Y-%m-%d %H:%M:%S"`
    mocaLinkLocalIpv4=`ifconfig $MOCA_INTERFACE | grep inet | tr -s ' ' | cut -d ' ' -f3 | sed -e 's/addr://g'`
    estbIp=`getIPAddress`
    gatewayMac=`getEstbMacAddress`
    gatewayInfo="{\"gatewayMac\":\"$gatewayMac\"},{\"gatewayEstbIp\":\"$estbIp\"},{\"gatewayMocav4Ip\":\"$mocaLinkLocalIpv4\"}"
    gatewayInfo="$gatewayInfo,{\"Time\":\"$cur_time\"}"
    outputJson="{\"XG1v6_Xiv4_issueList\":[$gatewayInfo,$outputJson]}"
    if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
       CURL_CMD="curl -w '%{http_code}\n' -H \"Accept: application/json\" -H \"Content-type: application/json\" -X POST -d '$outputJson' -o \"$HTTP_FILENAME\" \"$SPLUNK_URL\" --cert-status --connect-timeout 30 -m 10 "
    else
       CURL_CMD="curl -w '%{http_code}\n' -H \"Accept: application/json\" -H \"Content-type: application/json\" -X POST -d '$outputJson' -o \"$HTTP_FILENAME\" \"$SPLUNK_URL\" --connect-timeout 30 -m 10 "
    fi
    logMessage "CURL_CMD: $CURL_CMD"
    ret= eval $CURL_CMD > $HTTP_CODE
    http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
    logMessage "HTTP RESPONSE CODE : $http_code" 
    if [ $http_code -eq 200 ]; then
        logMessage "List of clients connected in v4 mode uploaded to slpunk "
    fi
fi

# Sleep for 60 seconds to avoid quick restart of the service
sleep 60
# Clean up tmp files
rm -f $CONNECTED_DEVICE_LIST
rm -f $TMP_CONNECTED_DEVICE_LIST
rm -f $MOCA_V6_CLIENT_FILE
rm -f $EXECUTION_LOCK

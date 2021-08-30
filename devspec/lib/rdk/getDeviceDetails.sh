#!/bin/sh
##########################################################################
# If not stated otherwise in this file or this component's LICENSE
# file the following copyright and licenses apply:
#
# Copyright 2019 RDK Management
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
##########################################################################

# input arguments
command=$1
parameter=$2
logEnabled=$3

# internal variables
logFile="/opt/logs/getDeviceDetails.$$.log"
lockDir=/tmp/.getDeviceDetails.lock
lockPidFile=/tmp/.getDeviceDetails.lock/.lockPidFile
deviceDetailsCache=/tmp/.deviceDetails.cache

# to enable logging: uncomment out echo and comment out colon : 
logMsg()
{
	#echo "$(cat /proc/uptime | awk '{print $1}'): $0: $$: $(ps -o comm= $PPID): $PPID :: $1" >> $logFile
	:
}

logMsg "enter"

. /etc/include.properties
. /etc/device.properties
. $RDK_PATH/utils.sh

# get box IP address
# This function will be invoked for non-mediaclients and for the devices with WiFI Support
getBoxIPAddress()
{
    IPAddress=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -m 1 -v '127.0.0.1'`
}

getEthernetMacAddress()
{
    EtherMac=`ifconfig $ETHERNET_INTERFACE | grep $ETHERNET_INTERFACE | tr -s ' ' | cut -d ' ' -f5`
    EtherMac=`echo $EtherMac | sed  "s/ //g"`
}

getLocalTime()
{
   timeValue=`date`
   echo "$timeValue"
}       

getTimeZone()
{
  zoneValue=""
  if [ -f /opt/etc/saved_timezone ]; then
       zoneValue=`cat /opt/etc/saved_timezone | cut -d "=" -f2 | cut -d "," -f1`
  fi
  echo "$zoneValue"
}

getFWVersion()
{
   versionTag1=$FW_VERSION_TAG1
   versionTag2=$FW_VERSION_TAG2
   verStr=`cat /version.txt | grep ^imagename:$versionTag1`
   if [ $? -eq 0 ]
   then
       echo $verStr | cut -d ":" -f 2
   else
       cat /version.txt | grep ^imagename:$versionTag2 | cut -d ":" -f 2
   fi
}

# identifies whether it is a VBN or PROD build
getBuildType()
{
   echo $BUILD_TYPE |tr '[:lower:]' '[:upper:]'
}

getModelNum()
{
   echo $MODEL_NUM
}

getBluetoothMac()
{
    bluetooth_mac="00:00:00:00:00:00"
    if [ "$BLUETOOTH_ENABLED" = "true" ]; then
        bluetooth_mac=`getDeviceBluetoothMac`
    fi

    echo "$bluetooth_mac"
}

getRF4CEMac()
{
    rf4ce_mac="00:00:00:00:00:00:00:00"
}


executeServiceRequest()
{
   logMsg "exec service = $1"
   if [ "$1" != "all" ]; then
        lock
   fi

   case "$1" in
      "all")
		executeServiceRequest "estb_mac"
		executeServiceRequest "wifi_mac"
		executeServiceRequest "eth_mac"
		executeServiceRequest "model_number"
		executeServiceRequest "build_type"
		executeServiceRequest "imageVersion"
                executeServiceRequest "bluetooth_mac"

                while true
                do
                    if [ "$RF4CEMac" == "" ]; then
                        executeServiceRequest "rf4ce_mac"
                    fi

                    if [ "$IPAddress" == "" ] && [ "$WIFI_SUPPORT" == "true" ]; then
                        executeServiceRequest "boxIP"
                    fi
                    
                    if [[ "$DEVICE_TYPE" == "mediaclient" && "$WIFI_SUPPORT" == "true" && "$IPAddress" != "" ]]; then
                        [ "$logEnabled" == "true" ] && echo "getDeviceDetails:`uptime | cut -f1 -d ','`, Breaking the loop, Got IPAddress:$IPAddress"
                        break
                    elif [ $(cat /proc/uptime | cut -d ' ' -f1 | cut -d '.' -f1) -gt 360 ]; then
                        [ "$logEnabled" == "true" ] && echo "getDeviceDetails:`uptime | cut -f1 -d ','`, Breaking the loop, Uptime limit reached"
                        break
                    fi

                    sleep 3
                done
                ;;
      "boxIP" | "estb_ip")
		getBoxIPAddress
  		echo "$IPAddress" > /tmp/.boxIP
  		echo "$IPAddress" > /tmp/.estb_ip
                ;;
      "macAddress" | "estb_mac")
		MacAddress=`getEstbMacAddress`
  		echo "$MacAddress" > /tmp/.macAddress
  		echo "$MacAddress" > /tmp/.estb_mac
                ;;
      "eth_mac")
		getEthernetMacAddress
  		echo "$EtherMac" > /tmp/.eth_mac
                ;;
      "wifi_mac")
		WiFiMac=`ifconfig $WIFI_INTERFACE | grep $WIFI_INTERFACE | tr -s ' ' | cut -d ' ' -f5`
		echo "$WiFiMac" > /tmp/.wifi_mac
                ;;
      "model_number")
		modelNum=`getModelNum`
		echo "$modelNum" > /tmp/.model_number
                ;;
      "imageVersion")
		FWVersion=`getFWVersion`
  		echo "$FWVersion" > /tmp/.imageVersion
                ;;
      "build_type")
		buildType=`getBuildType`
  		echo "$buildType" > /tmp/.build_type
                ;;
      "bluetooth_mac")
                BluetoothMac=`getBluetoothMac`
                echo "$BluetoothMac" > /tmp/.bluetooth_mac
                ;;
      "rf4ce_mac")
                RF4CEMac=`getRF4CEMac`
                echo "$RF4CEMac" > /tmp/.rf4ce_mac
                ;;
      "top_labels")
  		echo 
                ;;
      "mid_labels")
  		echo 
                ;;
      "low_labels")
  		echo 
                ;;
      *)
		logMsg "Error: wrong parameter=\"$parameter\"! No actions. Exit."
                ;;
   esac

   if [ "$1" != "all" ] && [ "$1" != "" ]; then
        [ ! -f "$deviceDetailsCache" ] && executeServiceRequestOutput || sed -i 's/'"$1"'=.*/'"$1"'='`cat /tmp/.$1`'/' "$deviceDetailsCache"
        unlock
   fi
}

executeServiceRequestOutput()
{
	logMsg "output"

        printf "estb_mac=%s\nwifi_mac=%s\neth_mac=%s\nmodel_number=%s\nbuild_type=%s\nimageVersion=%s\nboxIP=%s\nbluetooth_mac=%s\nrf4ce_mac=%s\n" \
                 "$MacAddress" "$WiFiMac" "$EtherMac" "$modelNum" "$buildType" "$FWVersion" "$IPAddress" "$BluetoothMac" "$RF4CEMac" | sort > $deviceDetailsCache
}

updateMissingParameters()
{
        data=`sed -n '/=$/p' /tmp/.deviceDetails.cache | tr "=" " "`
        if [ "$data" != "" ]; then
            echo "$data" | while read -r param
            do
                if [ "$param" != "" ]; then
                    file=/tmp/.$param
                    [ -f $file ] && [ "`cat $file`" != "" ] && sed -i 's/'$param=.*'/'$param=`cat $file`'/' "$deviceDetailsCache"
                    [ ! -f $file ] || [ "`cat $file`" == "" ] && executeServiceRequest $param
                fi
            done
        fi
}

lock()
{
        locktime=0
	while ! mkdir "$lockDir" &>/dev/null ; do
		logMsg "wait to acquire lock"
                if [ -s $lockPidFile ];then
		    lockPid=$(cat $lockPidFile)
		    if [ $? == 0 ]; then
			if ! kill -0 $lockPid &>/dev/null; then
				unlock "terminated process $lockPid stale"
		  	fi
                    fi
                else
                    prev_locktime=$locktime
                    locktime=`date +%s -r $lockDir 2> /dev/null`
                    if [ $? == 0 ] && [ "$prev_locktime" == "$locktime" ]; then
                        unlock "terminated process"
                    fi
		fi
		sleep 2
	done
	echo "$$" > $lockPidFile
	logMsg "lock acquired successfully"
	trap 'unlock "active process"'  0 1 13 15 &>/dev/null
}

unlock()
{
	rm -rf "$lockDir"
	logMsg "$1 lock released successfully"
}

# execute service request with arguments
if [ "$command" != "" ]; then

     if [ ! -f $deviceDetailsCache ] || [ "`cat $deviceDetailsCache`" == "" ]; then
         executeServiceRequestOutput
     fi

     logMsg "execute service request with arguments: command=$command : parameter=$parameter"
     if [ "$command" == "refresh" ]; then
         [ "$parameter" == "" ] && parameter="all"
         executeServiceRequest "$parameter"
         if [ "$parameter" != "all" ]; then 
            file=/tmp/."$parameter"
            if [ -f "$file" ] && [ -f "$deviceDetailsCache" ] ; then
               value=$(cat "$file")
            fi
         fi
     elif [ "$command" == "read" ]; then
         [ "$parameter" == "" ] && parameter="all"
         if [ "$parameter" != "all" ] && [ "$parameter" != "" ]; then 
            file=/tmp/."$parameter"
            [ ! -f "$file" ] || [ "`cat $file`" == "" ] && executeServiceRequest "$parameter"
            [ -f "$deviceDetailsCache" ] && value=`cat $deviceDetailsCache | grep $parameter | cut -d "=" -f2`
            [ -f "$deviceDetailsCache" ] && [ "$value" == "" ] && sed -i 's/'$parameter=.*'/'$parameter=`cat $file`'/' $deviceDetailsCache

            [ -f "$file" ] && cat $file
         else
            [ ! -f "$deviceDetailsCache" ] && executeServiceRequest "all"
            updateMissingParameters
            cat $deviceDetailsCache
         fi
     else
	logMsg "Error: wrong command=\"$command\"! No actions. Exit."
     fi

     logMsg "execute service request with arguments: command=$command : parameter=$parameter : exit"
     exit 0
fi

logMsg "cache = $([ -s $deviceDetailsCache ] && echo available || echo empty) "

if [ -s $deviceDetailsCache ]; then
     logMsg "service complete. exit"
     exit 0
fi

# execute all services in one request if not completed
if [ ! -f $deviceDetailsCache ] || [ "`cat $deviceDetailsCache`" == "" ]; then
    executeServiceRequestOutput
fi
executeServiceRequest "all"

logMsg "exit"

exit 0



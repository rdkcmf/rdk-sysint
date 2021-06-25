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
if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
     . /lib/rdk/getSecureDumpStatus.sh
fi

REBOOTLOG="$LOG_PATH/ocapri_log.txt"
export PATH=$PATH:/sbin:/usr/sbin
CORE_LOG="$LOG_PATH/core_log.txt"

#This is need to set core path for yocto builds
if [ -f /etc/os-release ]; then
	export CORE_PATH=$CORE_PATH
fi

Timestamp()
{
    date +"%Y-%m-%d %T"
}

resetRebootFlag()
{
    message=$1
    echo `Timestamp` 'Rebooting the box'>>$REBOOTLOG;
    echo 0 > /opt/.rebootFlag
    echo `/bin/timestamp` ------------ $message ----------------- >> $REBOOTLOG
}  

# Return system uptime in seconds
Uptime()
{       
    cat /proc/uptime | awk '{ split($1,a,".");  print a[1]; }'
}

# get eSTB IP address
getIPAddress()
{
    if [ -f /tmp/estb_ipv6 ]; then
        ifconfig -a $DEFAULT_ESTB_INTERFACE | grep inet6 | tr -s " " | grep -v Link | cut -d " " -f4 | cut -d "/" -f1 | head -n1
    else
        ifconfig -a $ESTB_INTERFACE | grep inet | grep -v inet6 | tr -s " " | cut -d ":" -f2 | cut -d " " -f1 | head -n1
    fi

}

## get eSTB mac address 
getMacAddress()
{
    ifconfig -a $ESTB_INTERFACE | grep $ESTB_INTERFACE | tr -s ' ' | cut -d ' ' -f5
}

getMacAddressOnly()
{
    ifconfig -a $ESTB_INTERFACE | grep $ESTB_INTERFACE | tr -s ' ' | cut -d ' ' -f5 | sed 's/://g'
}

# argument is maximum time to wait in seconds
waitForDumpCompletion()
{
    waitTime=$1
    while [[ `dumpInProcess` == 'true' ]];
    do
        echo "Waiting for core dump completion." >> $CORE_LOG
        count=`expr $count + 1`
        sleep 1
        if [ $count -gt $waitTime ]; then
            echo "Core dump creation is taking more time than expected. Returning." >> $CORE_LOG
            return
        fi
    done
}

dumpInProcess()
{
    if [[ -n "`ls $CORE_PATH/*.gz.tmp 2>/dev/null`" ]]; then
        echo 'true'
    else
        echo 'false'
    fi
}

haveCoreToUpload()
{
    if [[ -n "`ls $CORE_PATH/*.gz.tmp 2>/dev/null`" ]] || [[ -n "`ls $CORE_PATH/*.gz 2>/dev/null`" ]]; then
        echo 'true'
    else
        echo 'false'
    fi
}

checkIpDefaultRoute()
{
    gwIpv6Moca=`ip -6 route | grep $MOCA_INTERFACE | awk '/default/ { print $3 }'`
   if [[ ! -z "$gwIpv6Moca" ]]; then
        echo "`/bin/timestamp` $gwIpv6Moca  ip route is there" >> /opt/logs/tr69agent.log
        return 1
    else
        gwIpv4Moca=`route -n | grep 'UG[ \t]' | grep $MOCA_INTERFACE | awk '{print $2}'`
       if [[ ! -z "$gwIpv4Moca" ]]; then
            echo "`/bin/timestamp` $gwIpv4Moca ip route is there" >> /opt/logs/tr69agent.log
            return 1
        else
            if [[ ! -z "$WIFI_INTERFACE" ]]; then
                gwIpv6Wifi=`ip -6 route | grep $WIFI_INTERFACE | awk '/default/ { print $3 }'`
           else
                echo "`/bin/timestamp` no wifi interface to continue checking for auto ip route" >> /opt/logs/tr69agent.log
                return 0
            fi
            if [[ !  -z "$gwIpv6Wifi" ]]; then
                echo "`/bin/timestamp` $gwIpv6Wifi  ip route is there" >> /opt/logs/tr69agent.log
                return 1
            else
               gwIpv4Wifi=`route -n | grep 'UG[ \t]' | grep $WIFI_INTERFACE | awk '{print $2}'`
               if [[ !  -z "$gwIpv4Wifi" ]]; then
                    echo "`/bin/timestamp` $gwIpv6Wifi  ip route is there" >> /opt/logs/tr69agent.log
                    return 1
                else
                    echo "`/bin/timestamp`  ip route is not there " >> /opt/logs/tr69agent.log
                    return 0
                fi
            fi
        fi
    fi
}

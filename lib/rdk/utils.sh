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

# Scripts having common utility functions
. /etc/include.properties
. /etc/device.properties
. /etc/env_setup.sh

if [ "$BUILD_TYPE" != "prod" ] && [ -f $PERSISTENT_PATH/rfc.properties ]; then
    . $PERSISTENT_PATH/rfc.properties
else
   . /etc/rfc.properties
fi

processCheck()
{
   count=`ps | grep $1 | grep -v grep | wc -l`
   if [ $count == 0 ]; then
        echo "1"
   else
        echo "0"
   fi
}

rebootFunc()
{
    #reboot
    if [[ $1 == "" ]] && [[ $2 == "" ]]; then
       process=`cat /proc/$PPID/cmdline`
       reason="Rebooting by calling rebootFunc of utils.sh script..."
    else
       process=$1
       reason=$2
    fi
    /rebootNow.sh -s $process -o $reason
}

Timestamp()
{
	    date +"%Y-%m-%d %T"
}

checkProcess()
{
  ps | grep $1 | grep -v grep
}

# Last modified time
getLastModifiedTimeOfFile()
{
    if [ -f $1 ] ; then
        stat -c '%y' $1 | cut -d '.' -f1 | sed -e 's/[ :]/-/g'
    fi
}

# Set the name of the log file using SHA1
setLogFile()
{
    fileName=`basename $6`
    echo $1"_mac"$2"_dat"$3"_box"$4"_mod"$5"_"$fileName
}

# Get the MAC address of the machine
getMacAddressOnly()
{
    ifconfig | grep $ESTB_INTERFACE |grep -v $ESTB_INTERFACE: | tr -s ' ' | cut -d ' ' -f5 | sed -e 's/://g'
}

# Get the SHA1 checksum
getSHA1()
{
    sha1sum $1 | cut -f1 -d" "

}

# IP address of the machine
getIPAddress()
{
if [ "$(getModel)" = "RPI" ]; then
     echo "Inside get ip address" >> $LOG_PATH/dcmscript.log
    if [ -f /tmp/wifi-on ]; then
        interface=`getWiFiInterface`
    else
        interface=`getMoCAInterface`
    fi
    if [ -f /tmp/estb_ipv6 ]; then
        ip addr show dev $interface | grep -i global | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d' | head -n1
    else
        ifconfig $interface | grep inet | tr -s ' ' | cut -d ' ' -f3 | sed -e 's/addr://g'
    fi
else
    if [ -f /tmp/estb_ipv6 ]; then
        ifconfig -a $DEFAULT_ESTB_INTERFACE | grep inet6 | tr -s " " | grep -v Link | cut -d " " -f4 | cut -d "/" -f1 | head -n1
    else
        ifconfig -a $ESTB_INTERFACE | grep inet | grep -v inet6 | tr -s ' ' | cut -d ' ' -f3 | sed -e 's/addr://g'
    fi
fi
}

getEstbMacAddress()
{
   ifconfig -a $ESTB_INTERFACE | grep $ESTB_INTERFACE | tr -s ' ' | cut -d ' ' -f5 | tr -d '\r\n'
}

# Return system uptime in seconds
Uptime()
{
     cat /proc/uptime | awk '{ split($1,a,".");  print a[1]; }'
}
getMoCAInterface()
{
        if [ -f $PERSISTENT_PATH/moca_interface ] && [ "$BUILD_TYPE" != "prod" ] ; then
                interface=`cat $PERSISTENT_PATH/moca_interface`
        else
                interface=$MOCA_INTERFACE
                if [ ! "$interface" ]; then
                     interface=eth0
                fi
        fi
        echo $interface
}
getWiFiInterface()
{
        if [ -f $PERSISTENT_PATH/wifi_interface ] && [ "$BUILD_TYPE" != "prod" ] ; then
                interface=`cat $PERSISTENT_PATH/wifi_interface`
        else
                interface=$WIFI_INTERFACE
        fi
        if [ ! "$interface" ]; then
                interface=wlan0
        fi
        echo $interface
}

getModel()
{
    model=`sh $RDK_PATH/getDeviceDetails.sh read model`
    echo $model
}

getECMMac()
{
  snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
  snmpwalk -O0Q -v 2c -c "$snmpCommunityVal" 192.168.100.1 -m IF-MIB IF-MIB::ifPhysAddress.2 | cut -d "=" -f2
}

checkWiFiModule()
{
  echo 0
}

checkAutoIpDefaultRoute()
{
    gwIpv6Moca=`ip -6 route | grep $MOCA_INTERFACE | awk '/default/ { print $3 }'`
    if [ ! -z "$gwIpv6Moca" ]; then
        echo "`/bin/timestamp` $gwIpv6Moca auto ip route is there" >> /opt/logs/gwSetupLogs.txt
        return 1
    else
        gwIpv4Moca=`route -n | grep 'UG[ \t]' | grep $MOCA_INTERFACE | awk '{print $2}' | grep 169.254`
        if [ ! -z "$gwIpv4Moca" ]; then
            echo "`/bin/timestamp` $gwIpv4Moca auto ip route is there" >> /opt/logs/gwSetupLogs.txt
            return 1
        else
            if [ ! -z "$WIFI_INTERFACE" ]; then
                gwIpv6Wifi=`ip -6 route | grep $WIFI_INTERFACE | awk '/default/ { print $3 }'`
            else
                echo "`/bin/timestamp` no wifi interface to continue checking for auto ip route" >> /opt/logs/gwSetupLogs.txt
                return 0
            fi
            if [ !  -z "$gwIpv6Wifi" ]; then
                echo "`/bin/timestamp` $gwIpv6Wifi auto ip route is there" >> /opt/logs/gwSetupLogs.txt
                return 1
            else                    
                gwIpv4Wifi=`route -n | grep 'UG[ \t]' | grep $WIFI_INTERFACE | awk '{print $2}' | grep 169.254`
                if [ !  -z "$gwIpv4Wifi" ]; then
                    echo "`/bin/timestamp` $gwIpv6Wifi auto ip route is there" >> /opt/logs/gwSetupLogs.txt
                    return 1
                else
                    echo "`/bin/timestamp` auto ip route is not there " >> /opt/logs/gwSetupLogs.txt
                    return 0
                fi
            fi
        fi
    fi
}

checkIpDefaultRoute()
{
    gwIpv6Moca=`ip -6 route | grep $MOCA_INTERFACE | awk '/default/ { print $3 }'`
   if [ ! -z “$gwIpv6Moca” ]; then
        echo “`/bin/timestamp` $gwIpv6Moca  ip route is there” >> /opt/logs/tr69agent.log
        return 1
    else
        gwIpv4Moca=`route -n | grep 'UG[ \t]' | grep $MOCA_INTERFACE | awk '{print $2}'`
       if [ ! -z “$gwIpv4Moca” ]; then
            echo “`/bin/timestamp` $gwIpv4Moca ip route is there” >> /opt/logs/tr69agent.log
            return 1
        else
            if [ ! -z “$WIFI_INTERFACE” ]; then
                gwIpv6Wifi=`ip -6 route | grep $WIFI_INTERFACE | awk '/default/ { print $3 }'`
           else
                echo “`/bin/timestamp` no wifi interface to continue checking for auto ip route” >> /opt/logs/tr69agent.log
                return 0
            fi
            if [ !  -z “$gwIpv6Wifi” ]; then
                echo “`/bin/timestamp` $gwIpv6Wifi  ip route is there” >> /opt/logs/tr69agent.log
                return 1
            else
               gwIpv4Wifi=`route -n | grep 'UG[ \t]' | grep $WIFI_INTERFACE | awk '{print $2}'`
               if [ !  -z “$gwIpv4Wifi” ]; then
                    echo “`/bin/timestamp` $gwIpv6Wifi  ip route is there” >> /opt/logs/tr69agent.log
                    return 1
                else
                    echo “`/bin/timestamp`  ip route is not there ” >> /opt/logs/tr69agent.log
                    return 0
                fi
            fi
        fi
    fi
}

getDeviceBluetoothMac()
{
    bluetooth_mac="00:00:00:00:00:00"
    hash hcitool >/dev/null 2>&1
    if [ $? -eq 0 ] ; then
        bluetooth_mac=`hcitool dev |grep hci |cut -d$'\t' -f3|tr -d '\r\n'`
    fi
    echo $bluetooth_mac
}

getRFCValueForTR181Param()
{
    tr181_status='false'
    TR181_PARAM_NAME=$1
    tr181_status=`/usr/bin/tr181Set  ${TR181_PARAM_NAME}  2>&1 > /dev/null`
    if [ $? -ne 0 ];then
        if [ -f ${TR181_STORE_FILENAME} ]; then
            echo "tr181Set doesnt work get TR181_PARAM_NAME from ${TR181_STORE_FILENAME} file" >&2
            tr181_status=`grep ${TR181_PARAM_NAME}'=' ${TR181_STORE_FILENAME} | cut -d "=" -f2`
        else
            echo "Error - ${TR181_STORE_FILENAME} file not available" >&2
            tr181_status='false'
        fi
    fi
    echo $tr181_status
}

# Flush the logger daemon buffers to the file
flushLogger()
{
    echo "[PID:$$ $(date -u +%Y/%m/%d-%H:%M:%S)]: [utils.sh] flushLogger is called" >> /opt/logs/core_log.txt
    # Flush journald buffers
    test -f '/etc/os-release' && which journalctl && journalctl --sync --flush
    # Separate journald logs to files
    nice -n 19 /lib/rdk/dumpLogs.sh
}

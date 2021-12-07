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
. /etc/common.properties

Timestamp()
{
	    date +"%Y-%m-%d %T"
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
    ifconfig | grep $INTERFACE | tr -s ' ' | cut -d ' ' -f5 | sed -e 's/://g'
}

# Get the SHA1 checksum
getSHA1()
{
    sha1sum $1 | cut -f1 -d" "

}

# IP address of the machine
getIPAddress()
{
    echo "Inside get ip address" >> $LOG_PATH/dcmscript.log
    ifconfig $INTERFACE | grep inet | tr -s ' ' | cut -d ' ' -f3 | sed -e 's/addr://g'
}

processCheck()
{
   ps -ef | grep $1 | grep -v grep > /dev/null 2>/dev/null 
   if [ $? -ne 0 ]; then
         echo "1"
   else
         echo "0"
   fi
}

getMacAddress()
{
     ifconfig | grep $INTERFACE | tr -s ' ' | cut -d ' ' -f5
} 

getEstbMacAddress()
{
     mac=`awk < /proc/cmdline '{ for (i=1; i<=NF; i++) print $i}' | grep comcast[\.]stbmacaddr | cut -d'=' -f 2`
     echo $mac
} 

rebootFunc()
{
    sync
    reboot -f
}

# Return system uptime in seconds
Uptime()
{
     cat /proc/uptime | awk '{ split($1,a,".");  print a[1]; }'
}

checkAutoIpDefaultRoute()
{

     gwIpv4=`route -n | grep 'UG[ \t]' | grep eth0 | awk '{print $2}'`
     if [ ! -z "$gwIpv4" ]; then
     echo "`/bin/timestamp` $gwIpv4 auto ip route is there" >> /opt/logs/gwSetupLogs.txt
     fi
     return 1


}


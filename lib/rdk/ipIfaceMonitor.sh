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

# This will monitor the ip interface based on ip route table and assign the
# ipaddress to use or restart services for any application.  
 
. /etc/device.properties

set -x

ifaceBackup=""

while true;
do

if [ ! -f /tmp/estb_ipv6 ]; then

  ifaceCurrent=`route -n | grep 'UG[ \t]' | awk 'NR==1{print $8}'`
  if [ "$ifaceCurrent" = "$MOCA_INTERFACE" ] || [ "$ifaceCurrent" = "$WIFI_INTERFACE" ];  then
    if [ -f /tmp/open_internet ]; then
      rm /tmp/open_internet
    fi
    gatewayIP=`route -n | grep 'UG[ \t]' | grep $ifaceCurrent | awk '{print $2}' | grep 169.254`
    gatewayIP=`echo $gatewayIP | head -n1 | awk '{print $1;}'`
    if [ "$gatewayIP" = "" ]; then
      ifaceCurrent=$ifaceCurrent":0"
    fi
  else
    touch /tmp/open_internet
  fi

  if [ ! -f /tmp/estb_ipv6 ]; then
    if [ "$ifaceBackup" != "$ifaceCurrent" ];  then
      echo "$ifaceCurrent" > /tmp/ifaceCurrentlyUsed
      echo "Timestamp : `/bin/timestamp` $ifaceCurrent"
      if [ ! -f /tmp/estb_ipv6 ]; then
        ipaddrCurrent=`ifconfig $ifaceCurrent 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://'`
      fi
      echo "$ipaddrCurrent" > /tmp/ipaddrCurrentlyUsed
      echo "Timestamp : `/bin/timestamp` $ipaddrCurrent"
      /bin/systemctl restart tr69agent.service
      ifaceBackup=$ifaceCurrent
    fi
  fi
else
  if [ -f /tmp/open_internet ]; then
    rm /tmp/open_internet
  fi

  if [ -f /tmp/ipaddrCurrentlyUsed ]; then
    rm /tmp/ipaddrCurrentlyUsed
  fi
fi


sleep 60

done

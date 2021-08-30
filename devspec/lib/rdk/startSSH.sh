#!/bin/sh
##########################################################################
# If not stated otherwise in this file or this component's LICENSE
# file the following copyright and licenses apply:
#
# Copyright 2018 RDK Management
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

. /etc/include.properties
. /etc/device.properties
. /lib/rdk/commonUtils.sh

loop=1
      while [ $loop -eq 1 ]
      do
           # check for interface
           ret=`ifconfig | grep $MOCA_INTERFACE | grep -v $MOCA_INTERFACE:0`
           if [ "$ret" ]; then
                # check for IP address
                ipAddress=`ifconfig $MOCA_INTERFACE |  grep inet | grep -v localhost | grep -v 127.0.0.1 |tr -s ' ' | cut -d ' ' -f3 | sed -e 's/addr://g'`
                if [ "$ipAddress" ] && [ "$ipAddress" != "$DEFAULT_IP" ]; then 
                       echo "ipAddress: $ipAddress"
                       loop=0
                else
                 udhcpc -i $MOCA_INTERFACE
                       sleep 5
                fi
           else
                sleep 5
           fi
     done

     if [ -e /sbin/dropbear ] || [ -e /usr/sbin/dropbear ] ; then
          if [ ! -e /etc/dropbear/dropbear_rsa_host_key ]; then
               mkdir -p /etc/dropbear
               dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
               dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
          fi
          dropbear -b  /etc/sshbanner.txt -a -p $ipAddress:22 &
     fi
     exit 0



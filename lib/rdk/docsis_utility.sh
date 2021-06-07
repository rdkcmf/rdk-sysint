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

while [ ! -f /tmp/estb_ipv4 ]
do
 if [ -f /tmp/estb_ipv6 ];then
      exit 0
 fi
 sleep 1
done
if [ -f /tmp/estb_ipv4 ];then
    echo "TLV_IP_MODE: IPv4 Mode..!"
    /usr/bin/udhcpc_opt43 -b -i $ESTB_INTERFACE -V OpenCable2.1 -p /tmp/udhcpc_wan.pid -x 0x7d:0000170f00
    /sbin/ifconfig $DEFAULT_ESTB_IF 192.168.17.10 netmask 255.255.255.0 up
    /sbin/ip addr add 192.168.17.10 255.255.255.0 dev $DEFAULT_ESTB_IF
    /sbin/route add 192.168.17.0 $ESTB_INTERFACE
else
    echo "Box is in IPv6 Mode: Quitting the udhcpc execution..!"
fi


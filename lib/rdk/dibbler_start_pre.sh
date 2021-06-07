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

/bin/touch /etc/resolv.conf
#/sbin/ifconfig $DEFAULT_ESTB_IF $DEFAULT_ESTB_IP netmask 255.255.255.0 up
/sbin/ip addr add $DEFAULT_ESTB_IP 255.255.255.0 dev $DEFAULT_ESTB_IF    
/sbin/route add $ECM_ROUTE_ADDR $ESTB_INTERFACE

## Function: removeIfNotLink
removeIfNotLink()
{
   if [ ! -h $1 ] ; then
        echo "Removing $1"
        rm -rf $1
   fi
}

if [ -f /tmp/estb_ipv6 ];then
    echo "TLV_IP_MODE: IPv6 Mode..!"
    if [ ! -f /etc/os-release ];then
        removeIfNotLink /var/lib/dibbler                                                
        if [ ! -e /var/lib/dibbler ]; then                                              
            echo "Linking dibbler with /tmp/dibbler"                                
            ln -s /tmp/dibbler /var/lib/dibbler                                     
        fi
    else
        if [ ! -h /tmp/dibbler ];then
            ln -s /etc/dibbler /tmp/dibbler
        fi
        chmod 644 /tmp/dibbler/radvd.conf
        mkdir -p /var/log/dibbler
    fi

    if [ -f /lib/rdk/prepare_dhcpv6_config.sh ]; then
        /lib/rdk/prepare_dhcpv6_config.sh
    fi
    mkdir -p /opt/dibbler
    mkdir -p /tmp/dibbler

    if [ -f /opt/dibbler/client-duid ]; then
       cp /opt/dibbler/client-duid /tmp/dibbler/client-duid
    fi

else
    echo "Box is in IPv4 Mode: Quitting the dibbler execution..!"
fi

exit 0

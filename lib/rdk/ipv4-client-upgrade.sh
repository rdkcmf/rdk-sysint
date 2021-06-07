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



if [ -f /tmp/estb_ipv4 ];then
     echo "STB is in IPv4 Mode Exiting..!"
     exit 0
fi

if [ ! -f /etc/os-release ];then
    if [ -f /tmp/.xi-upgrade-started ];then
        exit 0
    fi
fi

touch /tmp/.xi-upgrade-started

if [ -f /etc/device.properties ];then
     . /etc/device.properties
fi

mocaLinkLocalIpv6=""
mocaLinkLocalIpv4=""

while [ ! -f /tmp/estb_ipv6 ]
do
   sleep 5
   if [ -f /tmp/estb_ipv4 ];then
     exit 0
   fi
done

sleep 10

mkdir -p /opt/moca-lighttpd/www

# Check To ensure the IPv6 MOCA prefix for client devices
v6prefixfile=/tmp/dibbler/client-AddrMgr.xml
globalip=`grep -F "AddrPrefix" $v6prefixfile | cut -d ">" -f2 | cut -d "<" -f1 `
while [ -z "$globalip" ]
do
        sleep 10
        globalip=`grep -F "AddrPrefix" $v6prefixfile | cut -d ">" -f2 | cut -d "<" -f1 `
done

# Check to ensure IPv6 Global IP address on XG1 MOCA interface
mocaLinkLocalIpv6=`ifconfig $MOCA_INTERFACE | grep inet6 | grep -i "Global" | tr -s ' ' | cut -d ' ' -f4 |  sed -e "s|/.*||g"`
while [ ! "$mocaLinkLocalIpv6" ]
do
    mocaLinkLocalIpv6=`ifconfig $MOCA_INTERFACE | grep inet6 | grep -i "Global" | tr -s ' ' | cut -d ' ' -f4 |  sed -e "s|/.*||g"`
done

# IPv4 MOCA IP address search
mocaLinkLocalIpv4=`ifconfig $MOCA_INTERFACE | grep inet | tr -s ' ' | cut -d ' ' -f3 | sed -e 's/addr://g'`
while [ ! "$mocaLinkLocalIpv4" ]
do
    mocaLinkLocalIpv4=`ifconfig $MOCA_INTERFACE | grep inet | tr -s ' ' | cut -d ' ' -f3 | sed -e 's/addr://g'`
    sleep 5
done

sleep 10

echo '' > /tmp/lighttpd_moca_include.conf
# lighttpd bindng on IPv4 IPv6 MOCA Addresses
echo "server.bind       = \"[$mocaLinkLocalIpv6]\"" >> /tmp/lighttpd_moca_include.conf
echo "" >> /tmp/lighttpd_moca_include.conf
echo "\$SERVER[\"socket\"] == \"$mocaLinkLocalIpv4:50099\" {" >> /tmp/lighttpd_moca_include.conf
echo "#"  >> /tmp/lighttpd_moca_include.conf
echo "}" >> /tmp/lighttpd_moca_include.conf

sleep 2

# ntp server setup for xi3 ipv4 devices
echo "driftfile /etc/ntp.drift" > /tmp/ntp.conf
echo "server 127.127.1.0" >> /tmp/ntp.conf
echo "fudge 127.127.1.0 stratum 14" >> /tmp/ntp.conf
echo "interface ignore wildcard" >> /tmp/ntp.conf
echo "interface listen $mocaLinkLocalIpv4" >> /tmp/ntp.conf
echo "restrict default  kod nomodify notrap nopeer noquery" >> /tmp/ntp.conf

# Starting lighttpd & ntp
if [ -f /etc/os-release ];then
    if [ -f /usr/sbin/lighttpd ];then
        /usr/sbin/lighttpd -D -f /etc/lighttpd_moca.conf &
    else
        echo "Missing /usr/sbin/lighttpd Binary..!"
    fi
else
    if [ -f /usr/local/sbin/lighttpd ];then
        /usr/local/sbin/lighttpd -m /usr/local/lib -f /etc/lighttpd_moca.conf &
    else
        echo "Missing /usr/local/sbin/lighttpd Binary..!"
    fi
fi

ntpd -4 -c /tmp/ntp.conf -n & 

# Update iptables for xi3 to XG1 communications via lightttpd running on MOCA port 50099
# ipv6 iptables binary path setup
if [ ! -f /etc/os-release ];then
     IPV4_BIN=/sbin/iptables
else
     IPV4_BIN=/usr/sbin/iptables
fi

$IPV4_BIN -D INPUT -i $MOCA_INTERFACE -p tcp --dport 50099 -j ACCEPT
$IPV4_BIN -A INPUT -i $MOCA_INTERFACE -p tcp --dport 50099 -j ACCEPT
# Limit traffic for ntp request on MOCA Interface internal to device
$IPV4_BIN -D INPUT -i $MOCA_INTERFACE -p udp --dport 123 -j ACCEPT
$IPV4_BIN -A INPUT -i $MOCA_INTERFACE -p udp --dport 123 -j ACCEPT

if [ -f /etc/os-release ];then
    $IPV4_BIN -D PREROUTING -t nat -i $MOCA_INTERFACE -p tcp --dport http -j DNAT --to-destination "$mocaLinkLocalIpv4:50099"
    $IPV4_BIN -A PREROUTING -t nat -i $MOCA_INTERFACE -p tcp --dport http -j DNAT --to-destination "$mocaLinkLocalIpv4:50099"
    $IPV4_BIN -D PREROUTING -t nat -i $MOCA_INTERFACE -p tcp --dport https -j DNAT --to-destination "$mocaLinkLocalIpv4:50099"
    $IPV4_BIN -A PREROUTING -t nat -i $MOCA_INTERFACE -p tcp --dport https -j DNAT --to-destination "$mocaLinkLocalIpv4:50099"
else
    $IPV4_BIN -D PREROUTING -t nat -i $MOCA_INTERFACE -p tcp --dport 80 -j DNAT --to-destination "$mocaLinkLocalIpv4:50099"
    $IPV4_BIN -A PREROUTING -t nat -i $MOCA_INTERFACE -p tcp --dport 80 -j DNAT --to-destination "$mocaLinkLocalIpv4:50099"
    $IPV4_BIN -D PREROUTING -t nat -i $MOCA_INTERFACE -p tcp --dport 443 -j DNAT --to-destination "$mocaLinkLocalIpv4:50099"
    $IPV4_BIN -A PREROUTING -t nat -i $MOCA_INTERFACE -p tcp --dport 443 -j DNAT --to-destination "$mocaLinkLocalIpv4:50099"
fi

$IPV4_BIN -D PREROUTING -t nat -i $MOCA_INTERFACE -p udp --dport 123 -j DNAT --to-destination "$mocaLinkLocalIpv4:123"
$IPV4_BIN -A PREROUTING -t nat -i $MOCA_INTERFACE -p udp --dport 123 -j DNAT --to-destination "$mocaLinkLocalIpv4:123"

$IPV4_BIN -D FORWARD -p tcp -d $mocaLinkLocalIpv4 --dport 50099 -j ACCEPT
$IPV4_BIN -A FORWARD -p tcp -d $mocaLinkLocalIpv4 --dport 50099 -j ACCEPT

$IPV4_BIN -D FORWARD -p udp -d $mocaLinkLocalIpv4 --dport 123 -j ACCEPT
$IPV4_BIN -A FORWARD -p udp -d $mocaLinkLocalIpv4 --dport 123 -j ACCEPT


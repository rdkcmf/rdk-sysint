#! /bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2016 RDK Management, LLC. All rights reserved.
# ============================================================================
. /etc/include.properties
. $RDK_PATH/utils.sh
. /etc/device.properties

export PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/sbin:/usr/local/sbin

if [ $# -eq 0 ]; then
    echo " `/bin/timestamp` Interface not provided"
    exit 1
fi

# Arg1: interface name
interface=$1

# Arg2: This specifies the different scenario
# 1 dns servers change
# 2 estb change
# 3 ipv6 prefix change
# 4 bootup call (no xupnp restart required)
# 5 dibbler restart scenario, need xupnp restart required
scenario=$2
previousPrefix=""

process=`cat /proc/$PPID/cmdline`
echo "Trigger from $process"

LOCKFILE=/tmp/`basename $0`.lock
if [ -e ${LOCKFILE} ] && kill -0 `cat ${LOCKFILE}`; then
    echo "$0 is already running"
    exit
fi

# make sure the lockfile is removed when we exit and then claim it
trap "rm -f ${LOCKFILE}; exit" INT TERM EXIT
echo $$ > ${LOCKFILE}

sysctl -w "net.ipv6.conf.all.forwarding=1"
sysctl -w "net.ipv6.conf.default.forwarding=1"

if [ "$IPV6_INTERFACE" ];then
     ESTB_INTERFACE=$IPV6_INTERFACE
fi

sysctl -w "net.ipv6.conf.$ESTB_INTERFACE.accept_ra=2"
sysctl -w "net.ipv6.conf.$ESTB_INTERFACE.autoconf=0"


# Clear any gloabal prefix address is present
currentGlobalIp=`ifconfig $interface | grep inet6 | grep -i "Global" | tr -s ' ' | cut -d ' ' -f4`
if [ ! -z  "$currentGlobalIp" ]; then
     echo " `/bin/timestamp` Clearing existing prefix $currentGlobalIp from interface $interface"
     ip -6 addr del $currentGlobalIp dev $interface
fi

estbIpAddress=""
# non-mediaclient devices
while [ ! "$estbIpAddress" ]
do
    if [ -f /tmp/estb_ipv6 ]; then
        estbIpAddress=`ifconfig -a $DEFAULT_ESTB_INTERFACE | grep inet6 | tr -s " " | grep -v Link | grep Global | head -n 1| cut -d " " -f4 | cut -d "/" -f1`
    else
         sleep 5
    fi
done

echo "Confirmed ESTB IP address: $estbIpAddress on $DEFAULT_ESTB_INTERFACE Interface"
if [ -f /tmp/ipv6_global_prefix.txt ]; then
    previousPrefix=`cat /tmp/ipv6_global_prefix.txt`
    echo "IPV6_PREFIX Before Parsing the DHCPv6 Response: `cat /tmp/ipv6_global_prefix.txt`"
fi

v6prefixfile=/tmp/dibbler/client-AddrMgr.xml
globalip=`grep -F "AddrPrefix" $v6prefixfile | cut -d ">" -f2 | cut -d "<" -f1 `
while [ -z "$globalip" ]
do
     	sleep 10
	echo " `/bin/timestamp`  sleeping for getting prefix "
	globalip=`grep -F "AddrPrefix" $v6prefixfile | cut -d ">" -f2 | cut -d "<" -f1 `
done

if [ -f $v6prefixfile ]; then
    echo "============================================="
    t1t2Timeout=`grep -i 'AddrIA unicast' $v6prefixfile`
    lifeTime=`grep -i 'AddrAddr timestamp' $v6prefixfile`
    duid=`cat /tmp/dibbler/client-duid`
    echo "dhcp server response "
    echo "$t1t2Timeout"
    echo "$lifeTime"
    echo "DUID : $duid"
    echo "============================================="
fi

echo " `/bin/timestamp` prefix = $globalip "
# Save current prefix for tracking ipv6 prefix changes  
echo "$globalip" > /tmp/ipv6_global_prefix.txt
num='1'
globalip=$globalip$num
echo " `/bin/timestamp` Adding existing prefix $globalip for interface $interface"
ip -6 addr add $globalip/64 dev $interface
touch /tmp/moca_ip_acquired

prefixAddress=`echo "${globalip%?}"`
echo "Prefix Check Info: $globalip $previousPrefix $prefixAddress"

# XUPNP Restart scenarios
# 1 dns servers change
# 2 estb change
# 3 ipv6 prefix change
# 4 bootup call (no xupnp restart required)
# 5 dibbler restart scenario, need xupnp restart required
if [ $scenario -eq 2 ] || [ $scenario -eq 3 ] || [ $scenario -eq 5 ] && [ "$prefixAddress" != "$previousPrefix" ];then
     echo "`/bin/timestamp`: Restarting upnp services for publishing New Data: $scenario"
     if [ -f /etc/os-release ]; then
           /bin/systemctl restart xcal-device.service
     else
           /etc/init.d/start-upnp-service restart
     fi
     echo "`/bin/timestamp` Completed upnp restart !!!"
fi

# Removing the lock file
if [ -f ${LOCKFILE} ];then rm -f ${LOCKFILE}; fi

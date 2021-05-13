#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2016 RDK Management, LLC. All rights reserved.
# ============================================================================
#
. /etc/include.properties
logsFile=$LOG_PATH/gwSetupLogs.txt

## Moca state capture duration in seconds
MOCA_CAPTURE_DURATION=60
PING6=/bin/ping6
IP=/sbin/ip

gwIf=$1
gatewayIPv6=$2

# exit if an instance is already running
if [ ! -f /tmp/.moca_state.pid ];then
    # store the PID
    echo $$ > /tmp/.moca_state.pid
else
    pid=`cat /tmp/.moca_state.pid`
    if [ -d /proc/$pid ];then
        exit 0
    fi
fi

export PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/sbin:/usr/local/lighttpd/sbin:/usr/local/sbin

echo "=============== `/bin/timestamp` Current device state  =================" >> $logsFile
echo "IPv6 Neighbour Show : " >> $logsFile
$IP -6 neigh show >> $logsFile
echo "IPv6 Routing Entry : " >> $logsFile
$IP -6 route show >> $logsFile
echo "IPv4 arp entry : " >> $logsFile
arp -a >> $logsFile
echo "IPv4 Routing Entry : " >> $logsFile
route -n >> $logsFile
ifconfig $gwIf >> $logsFile

if [ -d /proc/sys/net/ipv6/conf/$gwIf ]; then
    echo "    ======== Ipv6 Kernel Config Entries are : " >> $logsFile
    head -n1 /proc/sys/net/ipv6/conf/$gwIf/* | sed '/^\s*$/d' >> $logsFile
    echo "    ======== End of Kernel Config Entries ===== " >> $logsFile
fi

echo "=============== `/bin/timestamp` Start of moca packet capture ==================" >> $logsFile
if [ -f /usr/bin/mocap ] && [ -f /opt/moca_debug_enable ]; then
   /usr/bin/mocap get --link >> $logsFile
   /usr/bin/mocap get --preferred_nc >> $logsFile
   ## Enable moca trace
   echo "`/bin/timestamp` Starting moca trace capture for $MOCA_CAPTURE_DURATION seconds." >> $logsFile
   mocacfg log_forever 1
   sleep $MOCA_CAPTURE_DURATION
   result=`mocacfg log_stop | head -n1`
   echo "`/bin/timestamp` moca traces are captured in ${result##* }" >> $logsFile
fi

## Enable packet capture on moca interface with ping requests on linklocal gateway address
if [ -f /usr/sbin/tcpdump ] && [ -f /opt/enable_tcpdump ]; then
    mocaPcapture="moca.pcap"
    mocaPcapture=$LOG_PATH/$mocaPcapture
    tcpdump -i $gwIf -w $mocaPcapture &
    $PING6 -q -w $MOCA_CAPTURE_DURATION -I "$gwIf" "$gatewayIPv6" >> $logsFile
    killall -9 tcpdump
    echo "`/bin/timestamp` Packets on MoCA interface is captured in file $mocaPcapture" >> $logsFile
else
    echo "`/bin/timestamp` tcpdump utility is either not available or tcpdump is not enabled. Skipping packet capture" >> $logsFile
fi
echo "=============== `/bin/timestamp` End of moca packet capture ==================" >> $logsFile
echo "=============== `/bin/timestamp` End of state capture ==================" >> $logsFile

if [ -f /tmp/.moca_state.pid ];then
    rm -rf /tmp/.moca_state.pid
fi

exit 0

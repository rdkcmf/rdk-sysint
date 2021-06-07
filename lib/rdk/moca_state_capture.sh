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

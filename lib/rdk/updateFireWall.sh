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
. /etc/device.properties

PROCESS_NAME=$1
PORTS=$2 # optional single port number, ALL for all process ports (default is ALL)
PROTO=$3 # optional protocol type UDP, TCP, BOTH (default is BOTH)
INTERFACE=$4 # optional interface variable defined in device.properties (default is MOCA_INTERFACE)
MAX_RETRY=10

if [ -z $PORTS ]; then
    PORTS=ALL
fi

if [ -z $PROTO ]; then
    PROTO=BOTH
fi

if [ -z $INTERFACE ]; then
    INTERFACE=MOCA_INTERFACE
fi

getPortUsedByProcess() {
   processName=$1
   processPid=`pidof $processName`
   # Port listing should be unique and no restriction on the sount
   portUsedByProcess=`netstat -lntup 2>&1 | grep -v 'netstat' | grep "$processPid/" | tr -s ' ' | cut -d ' ' -f4 | cut -d ':' -f2 | uniq`
   echo "$portUsedByProcess"
}

if [ ! "$PROCESS_NAME" ]; then
    echo "Process name is empty. Exiting !!!!"
fi

if [ $PORTS == "ALL" ]; then
    loop=1
    retryCount=0
    while [ $loop -eq 1 ]
    do
        PORTS=$(getPortUsedByProcess $PROCESS_NAME)
        if [ ! "$PORTS" ]; then
            echo "Port used by $PROCESS_NAME is empty. Waiting for $PROCESS_NAME to be up !!! "
            sleep 10
            retryCount=$((retryCount + 1))
            if [ $retryCount -ge $MAX_RETRY ] ; then
                echo "Waiting for port identification used by $PROCESS_NAME failed. Giving up..."
                loop=0
                exit 0
            fi
        else
            loop=0;
        fi
    done
fi

# Enable firewall rule to accept traffic on port over MOCA interface  
if [ ! -f /etc/os-release ];then
     IPV6_BIN="/sbin/ip6tables -w "
     IPV4_BIN="/sbin/iptables -w "
else
     IPV6_BIN="/usr/sbin/ip6tables -w "
     IPV4_BIN="/usr/sbin/iptables -w "
fi

echo "Ports used by $PROCESS_NAME on interface $INTERFACE are : "
echo "$PORTS"

for i in $PORTS ; do

    # Avoid errors due to adding firewall rule on string observed during race around condition
    if [ "${i//[0-9]}" != "" ]; then
        echo "$i is not a valid port. "
        continue
    fi

    if [[ $PROTO == "BOTH" || $PROTO == "TCP" ]]; then
        $IPV4_BIN -A INPUT -i $(eval echo "\$${INTERFACE}") -p tcp --dport $i -j ACCEPT
        $IPV6_BIN -A INPUT -i $(eval echo "\$${INTERFACE}") -p tcp --dport $i -j ACCEPT
    fi

    if [[ $PROTO == "BOTH" || $PROTO == "UDP" ]]; then
        $IPV4_BIN -A INPUT -i $(eval echo "\$${INTERFACE}") -p udp --dport $i -j ACCEPT
        $IPV6_BIN -A INPUT -i $(eval echo "\$${INTERFACE}") -p udp --dport $i -j ACCEPT
    fi
done


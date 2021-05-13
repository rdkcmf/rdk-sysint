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

if [ -f /etc/device.properties ];then
     . /etc/device.properties
fi

if [ -f /lib/rdk/commonUtils.sh ];then
     . /lib/rdk/commonUtils.sh
fi

RESOLV_CONF='/etc/resolv.dnsmasq'
TEMP_RESOLV_CONF='/tmp/resolv.dnsmasq.bkp'

DHCP_SERVER_UPDATE_TYPE=$1
LOG_FILE="/opt/logs/dibbler.log"

echo "`/bin/timestamp` DHCP Server response type is : $DHCP_SERVER_UPDATE_TYPE" >> $LOG_FILE
echo "`/bin/timestamp` Response obtained from REMOTE_ADDR : $REMOTE_ADDR,  CLNT_MESSAGE : $CLNT_MESSAGE" >> $LOG_FILE



scenario=0

# Update DNS entries with values obatined from DHCP server
if [ -n "$SRV_OPTION23" ]; then
    R=""
    BIND_R=""
    for i in $SRV_OPTION23; do
	R="${R}nameserver $i
	"
	BIND_R="$BIND_R \n$i;"
    done
    echo -n "$R" > "$RESOLV_CONF"
    sh /lib/rdk/update_namedoptions.sh $BIND_R
    
    if [ ! -f /tmp/resolv.dnsmasq.bkp ];then
         cp $RESOLV_CONF $TEMP_RESOLV_CONF
    fi
    if [ "$DHCP_SERVER_UPDATE_TYPE" = "add" ] || [ "$DHCP_SERVER_UPDATE_TYPE" = "update" ] ; then
	 if cmp -s $RESOLV_CONF $TEMP_RESOLV_CONF >/dev/null ; then
             echo "No Change in DNS Servers" >>$LOG_FILE
         else
             cp $RESOLV_CONF $TEMP_RESOLV_CONF
             # Clients will get data as part of normal boot-up sequence
             # Updated data needs to be published only if there is dynamic runtime update from server
             if [ "x$DEVICE_NAME" != "xRNG150" ]; then  
                  # DNS servers change
                  scenario=1
                  echo "`/bin/timestamp` DNS entries are updated" >> $LOG_FILE
             fi
         fi
    fi
fi

# Reloading the dnsmasq config and clearing the cache
pkill -HUP dnsmasq

# restart dropbear when there is a change in estb ipv6
if [ ! -f /etc/os-release ];then
    CURRENT_IP=`getIPAddress`
    echo "`basename $0`: CURRENT IP: $CURRENT_IP" >> $LOG_FILE

    if [ -f /tmp/ipv6_address.txt ]; then
        PREVIOUS_IP=$(cat /tmp/ipv6_address.txt)
        echo "Identified ESTB IP Change. Previous IP : $PREVIOUS_IP  Current IP : $CURRENT_IP" >> $LOG_FILE
        if [ ! "$CURRENT_IP" ];then echo "Current Address is Empty: $CURRENT_IP" >> $LOG_FILE ; fi
        if [ ! "$PREVIOUS_IP" ];then echo "Previous Address is Empty: $PREVIOUS_IP" >> $LOG_FILE ; fi

        if [ "$CURRENT_IP" != "$PREVIOUS_IP" ] && [ "$CURRENT_IP" != "" ] && [ "$PREVIOUS_IP" != "" ]; then
            touch /tmp/ip_address_changed
            echo "$CURRENT_IP" > /tmp/ipv6_address.txt
            echo "Identified ESTB IP Change. Previous IP : $PREVIOUS_IP  Current IP : $CURRENT_IP" >> $LOG_FILE

            #Restart dropbear
            echo "Restarting dropbear.service" >> $LOG_FILE
            killall dropbear
            sh /lib/rdk/startSSH.sh &

            # Update ESTB IP Bound FireWall
            echo "Renewing firewal rules bound to ESTB IP " >> $LOG_FILE
            sh /lib/rdk/iptables_init "Refresh"
            scenario=2
        fi
    else
        echo "$CURRENT_IP" > /tmp/ipv6_address.txt
    fi
fi


if [ "x$DEVICE_NAME" != "xRNG150" ]; then
  v6prefixfile=/tmp/dibbler/client-AddrMgr.xml
  if [ -f $v6prefixfile ]; then
      CURRENT_IPv6_PREFIX=`grep -F "AddrPrefix" $v6prefixfile | cut -d ">" -f2 | cut -d "<" -f1 `
  else
      echo "Not found /tmp/dibbler/client-AddrMgr.xml, waiting for response" >> $LOG_FILE
  fi

  if [ ! -z "$CURRENT_IPv6_PREFIX" ]; then
    if [ -f /tmp/ipv6_global_prefix.txt ]; then
        # Check for prefix change and renew the moca prefix and restart xcal service
        echo "`/bin/timestamp` Checking for IPv6 prefix change from dibbler-client post script" >> $LOG_FILE
        PREVIOUS_IPV6_PREFIX=`cat /tmp/ipv6_global_prefix.txt`
        echo "PREVIOUS_IPV6_PREFIX = $PREVIOUS_IPV6_PREFIX     CURRENT_IPv6_PREFIX = $CURRENT_IPv6_PREFIX" >> $LOG_FILE
        if [ "$CURRENT_IPv6_PREFIX" != "$PREVIOUS_IPV6_PREFIX" ]; then
            # IPv6 address prefix change
            scenario=3
            # Deleting the previous iptable rule
            num='1'
            previous_ip=$PREVIOUS_IPV6_PREFIX$num
            command=`which ip6tables`
            if [ ! $command ];then 
                echo “Not Found the binary ip6tables”
            else
                $command -D OUTPUT -o $ESTB_INTERFACE -s “$previous_ip” -j DROP 
            fi
            echo "`/bin/timestamp` Identified IPv6 prefix change from DHCP server !!! Re-assigning MoCA IPv6 prefix" >> $LOG_FILE
            if [ -f /etc/os-release ];then
                /lib/rdk/getv6ip.sh ${MOCA_INTERFACE} $scenario >> $LOG_FILE
            else
                /lib/rdk/getv6ip.sh ${MOCA_INTERFACE} $scenario >> $LOG_FILE 2>&1 
            fi
        fi
    else
        # Normal bootup scenario
        scenario=4
        echo "`/bin/timestamp` Bootup Prefix Backup: $CURRENT_IPv6_PREFIX" >> $LOG_FILE
        echo "$CURRENT_IPv6_PREFIX" > /tmp/ipv6_global_prefix.txt
        if [ -f /etc/os-release ];then
                /lib/rdk/getv6ip.sh ${MOCA_INTERFACE} $scenario >> $LOG_FILE &
        else
                /lib/rdk/getv6ip.sh ${MOCA_INTERFACE} $scenario >> $LOG_FILE 2>&1 &
        fi
    fi
  else
    echo "Empty IPv6 Prefix: $CURRENT_IPv6_PREFIX from /tmp/dibbler/client-AddrMgr.xml" >> $LOG_FILE
    if [ -f /tmp/ipv6_global_prefix.txt ] && [ -s /tmp/ipv6_global_prefix.txt ];then
         # Dibbler restart scenario
         scenario=5
    else
         echo "Normal Bootup, delay in getting /tmp/dibbler/client-AddrMgr.xml" >> $LOG_FILE
    fi
    echo "`/bin/timestamp` Prefix will set in IPv6 MOCA address assignment: $CURRENT_IPv6_PREFIX" >> $LOG_FILE
    if [ -f /etc/os-release ];then
           /lib/rdk/getv6ip.sh ${MOCA_INTERFACE} $scenario >> $LOG_FILE &
    else
           /lib/rdk/getv6ip.sh ${MOCA_INTERFACE} $scenario >> $LOG_FILE 2>&1 &
    fi
  fi
fi


# XUPNP Restart scenarios
# 1 dns servers change
# 2 estb change
# 3 ipv6 prefix change
# 4 bootup call (no xupnp restart required)
# 5 dibbler restart scenario, need xupnp restart required
if [ $scenario -eq 1 ];then
     echo "`/bin/timestamp`: Restarting upnp services for publishing New Data: $scenario"
     if [ -f /etc/os-release ]; then
           /bin/systemctl restart xcal-device.service
     else
           /etc/init.d/start-upnp-service restart
     fi
     echo "`/bin/timestamp` Completed upnp restart !!!"
fi

touch /tmp/moca_ip_acquired

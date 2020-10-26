#!/bin/sh

if [ -f /etc/device.properties ];then
     . /etc/device.properties
fi

RESOLV_CONF='/etc/resolv.dnsmasq'
TEMP_RESOLV_CONF='/tmp/resolv.dnsmasq.bkp'

DHCP_SERVER_UPDATE_TYPE=$1
LOG_FILE="/opt/logs/dibbler.log"

echo "`/bin/timestamp` DHCP Server response type is : $DHCP_SERVER_UPDATE_TYPE" >> $LOG_FILE
echo "`/bin/timestamp` Response obtained from REMOTE_ADDR : $REMOTE_ADDR,  CLNT_MESSAGE : $CLNT_MESSAGE" >> $LOG_FILE

if [ "$ADDR1" != "" ]; then
    echo "`/bin/timestamp` Address obtained: ${ADDR1}" >> $LOG_FILE
fi

if [ "$PREFIX1" != "" ]; then
    echo "`/bin/timestamp` Prefix obtained: ${PREFIX1}" >> $LOG_FILE
fi

scenario=0

# Update DNS entries with values obatined from DHCP server
if [ -n "$SRV_OPTION23" ]; then
    R=""
    for i in $SRV_OPTION23; do
	R="${R}nameserver $i
"
    done
    echo -n "$R" > "$TEMP_RESOLV_CONF"
    echo -n "`/bin/timestamp` DNS Hosts: $R" >>  $LOG_FILE
fi

if [ "$OPTION_NEXT_HOP" != "" ]; then

    ip -6 route del default > /dev/null 2>&1
    ip -6 route add default via ${OPTION_NEXT_HOP} dev $IFACE
    echo "Added default route via ${OPTION_NEXT_HOP} on interface $IFACE/$IFINDEX" >> $LOG_FILE

fi

if [ "$OPTION_NEXT_HOP_RTPREFIX" != "" ]; then

    NEXT_HOP=`echo ${OPTION_NEXT_HOP_RTPREFIX} | awk '{print $1}'`
    NETWORK=`echo ${OPTION_NEXT_HOP_RTPREFIX} | awk '{print $2}'`
    #LIFETIME=`echo ${OPTION_NEXT_HOP_RTPREFIX} | awk '{print $3}'`
    METRIC=`echo ${OPTION_NEXT_HOP_RTPREFIX} | awk '{print $4}'`

    if [ "$NETWORK" == "::/0" ]; then

        ip -6 route del default > /dev/null 2>&1
        ip -6 route add default via ${OPTION_NEXT_HOP} dev $IFACE
        echo "Added default route via  ${OPTION_NEXT_HOP} on interface $IFACE/$IFINDEX" >> $LOG_FILE

    else

        ip -6 route add ${NETWORK} nexthop via ${NEXT_HOP} dev $IFACE weight ${METRIC}
        echo "Added nexthop to network ${NETWORK} via ${NEXT_HOP} on interface $IFACE/$IFINDEX, metric ${METRIC}" >> $LOG_FILE

    fi

fi

if [ "$OPTION_RTPREFIX" != "" ]; then

    ONLINK=`echo ${OPTION_RTPREFIX} | awk '{print $1}'`
    METRIC=`echo ${OPTION_RTPREFIX} | awk '{print $3}'`
    ip -6 route add ${ONLINK} dev $IFACE onlink metric ${METRIC}
    echo "Added route to network ${ONLINK} on interface $IFACE/$IFINDEX onlink, metric ${METRIC}" >> $LOG_FILE

fi

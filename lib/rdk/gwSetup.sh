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
. $RDK_PATH/utils.sh

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

#interface=`getMoCAInterface`
resolvFile=/etc/resolv.dnsmasq
upnp_resolvFile=/tmp/resolv.dnsmasq.upnp
preferGWFile=/opt/prefered-gateway
hostsFile=/etc/hosts
logsFile=$LOG_PATH/gwSetupLogs.txt
IPV6CALC=/usr/bin/ipv6calc
IP=/sbin/ip
PING6=/bin/ping6
ipv4File="/tmp/estb_ipv4"
ipv6File="/tmp/estb_ipv6"
ipv6PrefixFile="/tmp/ipv6prefix"


echo " `/bin/timestamp` ***************************START******************************" >> $logsFile
echo " `/bin/timestamp` GateWay IP = $1"   >> $logsFile
echo " `/bin/timestamp` DNS Config = $2"   >> $logsFile
echo " `/bin/timestamp` Gateway Interface = $3"   >> $logsFile
echo " `/bin/timestamp` Gw Priority = $4"   >> $logsFile
echo " `/bin/timestamp` Gateway IPv6 Prefix = $5" >> $logsFile
echo " `/bin/timestamp` Gateway v6 = $6" >> $logsFile
echo " `/bin/timestamp` DeviceType = $7" >> $logsFile

gatewayIP=$1
dns=$2
gwIf=$3
gwPrior=$4
gwIPv6Prefix=$5
gatewayIPv6=$6
deviceType=$7


## Moca state capture duration in seconds
MOCA_CAPTURE_DURATION=60

captureMocaState() {

    if [ -f /lib/rdk/moca_state_capture.sh ]; then
        /bin/sh /lib/rdk/moca_state_capture.sh "$gwIf" "$gatewayIPv6" &
    fi

}

# Verify the DNS servers list explicitly
dnsCheckAndUpdate()
{
    dns_temp=/tmp/resolv.upnp.bkp
    if [ "$dns" != "" ] && [ "$dns" != "null" ]; then
         :>$dns_temp #empty contents of resolvFile
         count=`echo "$dns" | awk -F\; {'print NF'}`
         echo `/bin/timestamp` $count >> $logsFile
         i=1
         while [ $i -le $count ]
         do
            dnsmasq=`echo $dns | cut -d \; -f $i`
            echo $dnsmasq >> $dns_temp
            i=`expr $i + 1`
         done
    fi
    cp $dns_temp $upnp_resolvFile
    echo "`/bin/timestamp`: New DNS Servers List: `cat $upnp_resolvFile`" >> $logsFile
}

if [ -f $preferGWFile ]; then
    preferred="`cat $preferGWFile`"
    echo " `/bin/timestamp` Preferred Gateway = $preferred" >> $logsFile
    if [ "$preferred" == "XB3" ]; then
        t2CountNotify "SYST_INFO_xb3_preferred"
        echo " `/bin/timestamp` exiting autoip route setup since preference is XB3" >> $logsFile
        exit 0;
#        if [ "$deviceType" == "XG2" ]; then
#            gwPrior=250
#        else
#            gwPrior=200
#        fi
    elif [ "$preferred" == "XG2" ]; then
        if [ "$deviceType" == "XG1" ]; then
            gwPrior=75
        else
            gwPrior=50
        fi
    else
        if [ "$deviceType" == "XG2" ]; then
            gwPrior=75
        else
            gwPrior=50
        fi
    fi
else
    echo " `/bin/timestamp` No Preferred Gateway so setting it as XG1" >> $logsFile
    echo "XG1" > $preferGWFile
    if [ "$deviceType" == "XG2" ]; then
        gwPrior=75
    else
        gwPrior=50
    fi
fi


if [ "$gwIPv6Prefix" == "" ] || [ "$gwIPv6Prefix" == "null" ]; then
    
    echo "`/bin/timestamp` IPv6 Prefix received from gateway is empty. Configuring device in IPv4 mode" >> $logsFile
    ##############   START - cleanup all the ipv6 stuffs before continuing with ipv4##################
    if [ -f "$ipv6File" ]; then
        exGwIp=`$IP -6 route | grep $gwIf | awk '/default/ { print $3 }'`
        echo "`/bin/timestamp` Device came in IPv6 mode previously " >> $logsFile
        echo "`/bin/timestamp` existing IPv6 gateway set in routing table entry is :  $exGwIp" >> $logsFile
        echo "`/bin/timestamp` gateway link local address received from gateway is $gatewayIPv6" >> $logsFile

	if [ "$exGwIp" != "$gatewayIPv6" ];then
	        $PING6 -c 3 -I "$gwIf" "$exGwIp"  > /dev/null
	        if [ $? -eq 0 ]; then
	        echo "`/bin/timestamp` existing ipv6 gateway $exGwIp is fine so not setting the new gateway $gatewayIP" >> $logsFile
	        echo "`/bin/timestamp` " >> $logsFile
	        echo " `/bin/timestamp` ***************************END******************************" >> $logsFile
		touch /tmp/moca_ip_acquired
	        exit 0
	        fi
	fi

        echo "Box was previously in IPV6 mode and now in IPv4 mode. Clearing flags $ipv6File !!!" >> $logsFile
        rm $ipv6File

        exIP=`ip -6 addr show "$gwIf" | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d' | sed  '/fe80/d'`
        echo " `/bin/timestamp` existing ip $exIP " >> $logsFile
        if [ ! -z "$exIP" ]; then
            echo " `/bin/timestamp` remove existing IPv6 IP : $exIP " >> $logsFile
            $IP -6 addr del "$exIP" dev $gwIf
        fi
        $IP -6 route del default dev $gwIf
        echo "since the box is changing to ipv4 mode removing existing default routes for IPv6" >> $logsFile
    fi
    ##############   END - cleanup all the ipv6 stuffs before continuing with ipv4##################
    
    echo "`/bin/timestamp`****** Box is in IPV4 mode *******" >> $logsFile
    gwIp=`route -n | grep 'UG[ \t]' | grep $gwIf | awk '{print $2}' | grep 169.254`
    count=`route -n | grep 'UG[ \t]' | grep $gwIf | grep 169.254 | awk '{print $5}' | wc -l`
    echo "count = $count" >> $logsFile
    if [ $count -ge 1 ]; then
        echo " `/bin/timestamp` multiple device existing as gw in routing table :  $exIP " >> $logsFile
        for item in $gwIp
        do
            exGwIp=""
            exGwIpPrior=`route -n | grep 'UG[ \t]' | grep $gwIf | grep 169.254 | grep $item | awk '{print $5}'`
            if [ "$exGwIpPrior" = "$gwPrior" ]; then
                    echo " `/bin/timestamp` already gateway is set for the same device " >> $logsFile
                    exGwIp=$item
                    break
            fi
        done
    else
        exGwIp=$gwIp
    fi
    #exGwIp=`route -n | awk '/default/ { print $3 }'| grep 169.254`
    if [ "$exGwIp" = "$gatewayIP" ]; then
        sh /lib/rdk/iptables_init 'Refresh_v4_ssh' &
        echo "`/bin/timestamp` $exGwIp is already set as route " >> $logsFile
        echo " `/bin/timestamp` ***************************END******************************" >> $logsFile
	touch /tmp/moca_ip_acquired
        exit 0
    fi
    if [ "$exGwIp" != "" ]; then
        hasGWPrior=`route -n  | grep 'UG[ \t]' | grep $gwIf | grep $exGwIp  | awk '{print $5}' `
        if [ "$exGwIpPrior" = "$gwPrior" ]; then
            ping -c 2 $exGwIp   > /dev/null 2>/dev/null
            if [  $? -eq 0 ]; then
                echo "`/bin/timestamp` existing gw $exGwIp is fine so discarding the new IP $gatewayIP " >> $logsFile
            else
                echo "`/bin/timestamp` Deleting the existing gateway ip $exGwIp and setting the new gateway $gatewayIP " >> $logsFile
    		touch $ipv4File
                echo "`/bin/timestamp` Creating IPv4 flags " >> $logsFile
                route del default gw $exGwIp dev $gwIf
                route add default gw $gatewayIP dev $gwIf  metric $gwPrior
    #   ip route add default via $gatewayIP dev $gwIf priority $gwPrior
        #       ip route del default via $exGwIp dev $gwIf
            fi
        else
    	    touch $ipv4File
            route add default gw $gatewayIP dev $gwIf  metric $gwPrior
            echo "`/bin/timestamp` new gateway ip for this device type $deviceType  " >> $logsFile
        fi
        sh /lib/rdk/iptables_init 'Refresh_v4_ssh' &
    else
        touch $ipv4File
        route add default gw $gatewayIP dev $gwIf  metric $gwPrior
        echo "`/bin/timestamp` Setting $gatewayIP as route " >> $logsFile
    fi

    if [ "$dns" != "" ] && [ "$dns" != "null" ]; then
        dnsCheckAndUpdate
        echo "`/bin/timestamp` $fileName : DNS setting written to resolv.conf" >> $logsFile
    else
        echo "`/bin/timestamp` $fileName : DNS Config is empty "  >> $logsFile
    fi
        /bin/systemctl restart tr69agent.service
        /bin/systemctl restart dropbear.service
#    if [ "$etchosts" != "" ] && [ "$etchosts" != "null" ]; then
#        :>$hostsFile #empty contents of hostsFile
#        echo `/bin/timestamp` $etchosts  >> $logsFile
#        count=`echo "$etchosts" | awk -F\; {'print NF'}`
#        echo `/bin/timestamp` $count   >> $logsFile
#        i=1
#        while [ $i -le $count ]
#        do
#            hosts=`echo $etchosts | cut -d \; -f $i`
#            echo $hosts >> $hostsFile
#            i=`expr $i + 1`
#        done
#        echo "127.0.0.1 localhost" >> $hostsFile
#        echo "`/bin/timestamp` $fileName Gateway hosts data  written to hosts file" >> $logsFile
#    else
#        echo "`/bin/timestamp` $fileName Hosts data is empty " >> $logsFile
#    fi
else
    
    echo "`/bin/timestamp` IPv6 Prefix received from gateway is non-empty. Configuring device in IPv6 mode" >> $logsFile
        ##############   START - cleanup ipv4 route ##################
    if [ -f "$ipv4File" ]; then
        echo "`/bin/timestamp` Device came in IPv4 mode previously " >> $logsFile
        exGwIp=`route -n | grep 'UG[ \t]' | grep $gwIf | awk '{print $2}' | grep 169.254`
        count=`route -n | grep 'UG[ \t]' | grep $gwIf | grep 169.254 | awk '{print $5}' | wc -l`
        echo "`/bin/timestamp` existing IPv4 gateway set in routing table entry is :  $exGwIp" >> $logsFile
        echo "count = $count" >> $logsFile
        if [ $count -ge 1 ]; then
           echo " `/bin/timestamp` cleaning up multiple ipv4 address $exGwIp " >> $logsFile
           for item in $exGwIp
           do
              ping -c 3 $item   > /dev/null                             
              if [  $? -eq 0 ]; then    
                echo "`/bin/timestamp` existing ipv4 gw $item is fine so discarding the new ipv6 route $gatewayIPv6" >> $logsFile
                echo " `/bin/timestamp` ***************************END******************************" >> $logsFile
		touch /tmp/moca_ip_acquired
                exit 0
              else
                echo "`/bin/timestamp` ping failed deleting v4 address $item  $gwIf"
                route del default gw $item dev $gwIf
              fi
            done
        else
              ping -c 3 $exGwIp   > /dev/null                             
              if [  $? -eq 0 ]; then    
                echo "`/bin/timestamp` existing ipv4 gw $exGwIp is fine so discarding the new ipv6 route $gatewayIPv6 " >> $logsFile
                echo " `/bin/timestamp` ***************************END******************************" >> $logsFile
		touch /tmp/moca_ip_acquired
                exit 0
              else
                echo "`/bin/timestamp` ping failed deleting v4 address $exGwIp $gwIf"
                route del default gw $exGwIp dev $gwIf
              fi
        fi
#        ping -c 3 $exGwIp   > /dev/null                             
#        if [  $? -eq 0 ]; then 
#            echo "`/bin/timestamp` existing ipv4 gw $exGwIp is fine so discarding the new ipv6 route"
#            echo " `/bin/timestamp` ***************************END******************************" >> $logsFile
#            exit 0
#        fi
        rm $ipv4File
        echo "`/bin/timestamp` Box was previously in IPV4 mode" >> $logsFile
        echo "`/bin/timestamp` since the box is changing to ipv6 mode removing existing default routes for IPv4" >> $logsFile
    fi
    ##############   END - cleanup  ipv4 route ##################


    echo "`/bin/timestamp` ****** Box is in IPV6 mode *******" >> $logsFile
    exGwIp=`$IP -6 route | grep $gwIf | awk '/default/ { print $3 }'`
    echo "`/bin/timestamp` existing gateway link local ip : $exGwIp" >> $logsFile
    v6prefix=`cat $ipv6PrefixFile`
    $PING6 -c 3 -I "$gwIf" "$exGwIp"  > /dev/null
    if [ $? -eq 0 ] ; then
       echo "`/bin/timestamp` existing gateway $exGwIp is fine check for prefix change" >> $logsFile
       if [ "$exGwIp" = "$gatewayIPv6" ]; then
          if [ "$v6prefix" = "$gwIPv6Prefix" ];then
            echo "`/bin/timestamp` existing gateway $exGwIp is fine no change in prefix $v6prefix $gwIPv6Prefix"   >> $logsFile
            dnsCheckAndUpdate
            echo " `/bin/timestamp` ***************************END******************************" >> $logsFile
	    touch /tmp/moca_ip_acquired
            exit 0
          else  
            echo "`/bin/timestamp` existing gateway $exGwIp is fine but there is a change in prefix from $v6prefix to $gwIPv6Prefix"   >> $logsFile
            if [ ! -f $IPV6CALC ]; then
                echo "`/bin/timestamp` $IPV6CALC not found, exiting!" >> $logsFile
                echo " `/bin/timestamp` ***************************END******************************" >> $logsFile
                exit 255
            fi
            echo $gwIPv6Prefix > $ipv6PrefixFile
            touch $ipv6File
            echo "`/bin/timestamp` continue with the new gateway $gatewayIPv6" >> $logsFile
            gwIf_MAC=`ifconfig "$gwIf" | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}'`
            echo "`/bin/timestamp` MAC address for $gwIf=$gwIf_MAC"  >> $logsFile
            gwIf_IPv4=`ifconfig "$gwIf" | grep inet | tr -s ' ' | cut -d ' ' -f3 | sed -e 's/addr://g' | head -n1`
            echo "`/bin/timestamp` IPv4 address for $gwIf=$gwIf_IPv4" >> $logsFile
            gwIf_IPv4=`printf '%02X' ${gwIf_IPv4//./ }`
            hexFormatedLowerBits=`echo $gwIf_IPv4 | sed -e 's/..../&:/g' -e 's/:$//'`
            echo "`/bin/timestamp` Hex formated lower 64-bit from Ipv4 address = $hexFormatedLowerBits" >> $logsFile
            IPV6PREFIXLEFT=`echo $gwIPv6Prefix| awk -F/ '{print $1}'`
            echo "`/bin/timestamp` IPV6PREFIXLEFT=$IPV6PREFIXLEFT" >> $logsFile
            GEN_IPV6ADDRESS=`$IPV6CALC --in prefix+mac --action prefixmac2ipv6 --out ipv6addr "$gwIPv6Prefix" "$gwIf_MAC"`
            echo "`/bin/timestamp` GEN_IPV6ADDRESS With IPv6 Calc = $GEN_IPV6ADDRESS" >> $logsFile
            #Replace lower two 64 bits with the one derived from IPv4 address
            GEN_IPV6ADDRESS=${GEN_IPV6ADDRESS%:*}
            GEN_IPV6ADDRESS=${GEN_IPV6ADDRESS%:*}
            GEN_IPV6ADDRESS="${GEN_IPV6ADDRESS}:${hexFormatedLowerBits}"
            echo "`/bin/timestamp` GEN_IPV6ADDRESS=$GEN_IPV6ADDRESS" >> $logsFile

            exIP=`ip -6 addr show "$gwIf" | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d' | sed  '/fe80/d'`
            echo " `/bin/timestamp` existing ip $exIP " >> $logsFile
            if [ ! -z "$exIP" ]; then

                echo " `/bin/timestamp` remove existing ip $exIP " >> $logsFile
                $IP -6 addr del "$exIP" dev $gwIf
            fi

             echo " `/bin/timestamp` Adding new IPv6 IP $GEN_IPV6ADDRESS to interface $gwIf " >> $logsFile
             $IP -6 addr add "$GEN_IPV6ADDRESS" dev $gwIf
            /bin/systemctl restart tr69agent.service
            /bin/systemctl restart dropbear.service

            # ping gateway link-local address
            $PING6 -c 3 -I "$gwIf" "$gatewayIPv6" > /dev/null
            if [ $? != 0 ]; then
                echo "`/bin/timestamp` ping6 to link local gateway address $gatewayIPv6 care of $gwIf failed" >> $logsFile
                captureMocaState
            fi

            $IP -6 route del default dev $gwIf
            echo "`/bin/timestamp` Removing existing default routes for IPv6" >> $logsFile

            $IP -6 route add ::/0 via "$gatewayIPv6" dev $gwIf
            echo "`/bin/timestamp` Adding IPv6 default route for IPv6 to $gatewayIPv6 via interface $gwIf" >> $logsFile
            echo "`/bin/timestamp` Routing entries are refreshed" >> $logsFile
            $PING6 -c 3 -I "$gwIf" "$gatewayIPv6" > /dev/null
            if [ $? != 0 ]; then
                echo "`/bin/timestamp` ping6 to link local gateway address $gatewayIPv6 care of $gwIf failed" >> $logsFile
            fi

            if [ "$dns" != "" ] && [ "$dns" != "null" ]; then
                dnsCheckAndUpdate
                echo "`/bin/timestamp` $fileName : DNS setting written to resolv.conf" >> $logsFile
            else
                echo "`/bin/timestamp` $fileName : DNS Config is empty "  >> $logsFile

            fi
          fi
       
       else
          echo "`/bin/timestamp` existing gateway is fine and new gateway is different so not going for prefix change check" >> $logsFile
          echo " `/bin/timestamp` ***************************END******************************" >> $logsFile
	  touch /tmp/moca_ip_acquired
          exit 0
       fi
    else
        if [ ! -f $IPV6CALC ]; then
            echo "`/bin/timestamp` $IPV6CALC not found, exiting!" >> $logsFile
            echo " `/bin/timestamp` ***************************END******************************" >> $logsFile
            exit 255
        fi
	echo $gwIPv6Prefix > $ipv6PrefixFile
        touch $ipv6File
        echo "`/bin/timestamp` continue with the new gateway $gatewayIPv6" >> $logsFile
        gwIf_MAC=`ifconfig "$gwIf" | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}'`
        echo "`/bin/timestamp` MAC address for $gwIf=$gwIf_MAC"  >> $logsFile
        gwIf_IPv4=`ifconfig "$gwIf" | grep inet | tr -s ' ' | cut -d ' ' -f3 | sed -e 's/addr://g' | head -n1`
        echo "`/bin/timestamp` IPv4 address for $gwIf=$gwIf_IPv4" >> $logsFile
        gwIf_IPv4=`printf '%02X' ${gwIf_IPv4//./ }`
        hexFormatedLowerBits=`echo $gwIf_IPv4 | sed -e 's/..../&:/g' -e 's/:$//'`
        echo "`/bin/timestamp` Hex formated lower 64-bit from Ipv4 address = $hexFormatedLowerBits" >> $logsFile
        IPV6PREFIXLEFT=`echo $gwIPv6Prefix| awk -F/ '{print $1}'`
        echo "`/bin/timestamp` IPV6PREFIXLEFT=$IPV6PREFIXLEFT" >> $logsFile
        GEN_IPV6ADDRESS=`$IPV6CALC --in prefix+mac --action prefixmac2ipv6 --out ipv6addr "$gwIPv6Prefix" "$gwIf_MAC"`
        echo "`/bin/timestamp` GEN_IPV6ADDRESS With IPv6 Calc = $GEN_IPV6ADDRESS" >> $logsFile
        #Replace lower two 64 bits with the one derived from IPv4 address
        GEN_IPV6ADDRESS=${GEN_IPV6ADDRESS%:*}
        GEN_IPV6ADDRESS=${GEN_IPV6ADDRESS%:*}
        GEN_IPV6ADDRESS="${GEN_IPV6ADDRESS}:${hexFormatedLowerBits}"
        echo "`/bin/timestamp` GEN_IPV6ADDRESS=$GEN_IPV6ADDRESS" >> $logsFile

        exIP=`ip -6 addr show "$gwIf" | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d' | sed  '/fe80/d'`
        echo " `/bin/timestamp` existing ip $exIP " >> $logsFile
        if [ ! -z "$exIP" ]; then
        
            echo " `/bin/timestamp` remove existing ip $exIP " >> $logsFile
            $IP -6 addr del "$exIP" dev $gwIf
        fi
    
        echo " `/bin/timestamp` adding new ip $GEN_IPV6ADDRESS to interface $gwIf " >> $logsFile
        $IP -6 addr add "$GEN_IPV6ADDRESS" dev $gwIf
        /bin/systemctl restart tr69agent.service
	/bin/systemctl restart dropbear.service

        # ping gateway link-local address
        $PING6 -c 3 -I "$gwIf" "$gatewayIPv6"  > /dev/null
        if [ $? != 0 ]; then
            echo "`/bin/timestamp` ping6 to $gatewayIPv6 care of $gwIf failed" >> $logsFile
            captureMocaState
        fi

        $IP -6 route del default dev $gwIf
        echo "`/bin/timestamp` Removing existing default routes for IPv6" >> $logsFile

        $IP -6 route add ::/0 via "$gatewayIPv6" dev $gwIf
        echo "`/bin/timestamp` Adding IPv6 default route for IPv6 to $gatewayIPv6 via $gwIf" >> $logsFile

        echo "`/bin/timestamp` Routing entries are refreshed" >> $logsFile
        $PING6 -c 3 -I "$gwIf" "$gatewayIPv6" > /dev/null
        if [ $? != 0 ]; then
            echo "`/bin/timestamp` ping6 to link local gateway address $gatewayIPv6 care of $gwIf failed" >> $logsFile
        fi

        if [ "$dns" != "" ] && [ "$dns" != "null" ]; then
            dnsCheckAndUpdate
            echo "`/bin/timestamp` $fileName : DNS setting written to resolv.conf" >> $logsFile
        else
            echo "`/bin/timestamp` $fileName : DNS Config is empty "  >> $logsFile
        fi
    fi
fi
if [ -f /tmp/usingdhcp ]; then
        rm -f /tmp/usingdhcp
fi
touch /tmp/usingautoip
echo " `/bin/timestamp` ***************************END******************************" >> $logsFile
exit 23

#!/bin/busybox sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2016 RDK Management, LLC. All rights reserved.
# ============================================================================

resolvFile=/etc/resolv.dnsmasq
udhcpc_resolvfile=/tmp/resolv.dnsmasq.udhcpc
composite_resolvFile=/tmp/bck_resolv.dnsmasq
upnp_resolvFile=/tmp/resolv.dnsmasq.upnp
dnsmasq_sorted=/tmp/.dnsmasq.sorted

#Waiting for the lock to release
while [ -f /var/lock/dnsmerge.lock ];
do
    sleep 1
done;

#Acquire the lock
touch /var/lock/dnsmerge.lock

:>$composite_resolvFile #empty contents of resolvFile

_sort()
{
    cat $1 | sort > $dnsmasq_sorted
    cp $dnsmasq_sorted $1
    rm -rf $dnsmasq_sorted
}

for resolver in `ls /tmp/resolv.dnsmasq.* | grep -v $composite_resolvFile`
do
   if [ $resolver = $udhcpc_resolvfile ]  && [ -s $upnp_resolvFile ]; then
      continue
   fi
   if [ ! -s $composite_resolvFile ]; then
      cp $resolver $composite_resolvFile
   else
     awk 'NR==FNR{a[$0];next} !($0 in a)' $composite_resolvFile  $resolver >> $composite_resolvFile 
   fi
done

if [ ! -s $composite_resolvFile ]; then
   cp $udhcpc_resolvfile $composite_resolvFile
fi

#Sorting both original and newly updated content to avoid unnecessary restart of dnsmasq.service
_sort $composite_resolvFile
_sort $resolvFile

if diff $composite_resolvFile $resolvFile >/dev/null ; then 
    echo "No Change in DNS Servers" 
else
    if [ -s $composite_resolvFile ];then
         cat $composite_resolvFile > $resolvFile 
         echo "DNS Servers Updated" 
	 ipv4=0
	 ipv6=0
	 DNS_ADDR=""
	 while read -r line; do
		 ADDR=`echo $line | cut -d " " -f2`
		 if [ "$line" != "${line#*[0-9].[0-9]}" ]; then
			 ipv4=$((ipv4 +1))
			 DNS_ADDR="$DNS_ADDR \n$ADDR;"
		elif [ "$line" != "${line#*:[0-9a-fA-F]}" ]; then
			 ipv6=$((ipv6 +1))
			 DNS_ADDR="$DNS_ADDR \n$ADDR;"
		 else
			 echo "Unrecognized IP format '$line'"
		 fi
	 done<$resolvFile

	 if [ "x$ipv4" = "x0" -a -f /lib/rdk/update_namedoptions.sh ]; then
		 /bin/sh /lib/rdk/update_namedoptions.sh $DNS_ADDR

	 else
		 # This is to handle switching between ipv4 and ipv6
		 systemctl stop named.service
		 systemctl restart dnsmasq.service
	 fi

    fi
fi

#Release the lock before leaving
rm -f /var/lock/dnsmerge.lock

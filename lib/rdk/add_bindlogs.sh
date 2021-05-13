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
### Adding support for named.log and dnsquery.log
if [ -f /tmp/.standby ];then
	exit 0
fi
if [ -f /var/cache/bind/named.log ];then
       cat /var/cache/bind/named.log >>/opt/logs/named.log
       : > /var/cache/bind/named.log
fi

if [ -f /var/cache/bind/querylog.txt ];then
       cat /var/cache/bind/querylog.txt >>/opt/logs/dnsquery.log
       : > /var/cache/bind/querylog.txt
fi


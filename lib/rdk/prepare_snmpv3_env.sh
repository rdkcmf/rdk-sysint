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

if [ -d /etc/snmpv3/certs ]; then
     mkdir -p /tmp/.snmp/tls/private

     if [ -f /usr/bin/GetConfigFile ]; then
         GetConfigFile /tmp/.snmp/tls/private/rdkv-snmpd.key
         if [ -f /tmp/.snmp/tls/private/rdkv-snmpd.key ]; then
             chmod 600 /tmp/.snmp/tls/private/rdkv-snmpd.key
             mv /tmp/.snmp/tls/private/rdkv-snmpd.key /tmp/.snmp/tls/private/rdkv-snmpdY22.key
             chmod 600 /tmp/.snmp/tls/private/rdkv-snmpdY22.key
         fi
         GetConfigFile /tmp/.snmp/tls/private/rdkv-snmpdV3.key
         if [ -f /tmp/.snmp/tls/private/rdkv-snmpdV3.key ]; then
             chmod 600 /tmp/.snmp/tls/private/rdkv-snmpdV3.key
         fi
     else
         echo "GetConfigFile not Found !!"
         exit 127
     fi

     #execute c_rehash in ca-certs folder to get hash files for CA-chain
#     echo "c_rehash in ca-certs folder to get hash files for CA-chain"
#     c_rehash /etc/ssl/certs/snmp/tls/ca-certs/
fi


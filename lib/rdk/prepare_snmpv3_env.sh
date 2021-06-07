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


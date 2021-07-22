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

CONFIG_FILE=/usr/bin/GetConfigFile
STATIC_CERT="/etc/ssl/certs/snmp/tls/certs/rdk-snmpv3-snmpd-xpki-v1.p12"
CFG_IN="/tmp/.snmp/tls/support/snmpv3staticxpki"
XPKIEXTRACT="/tmp/.snmpv3xpki"
XPKIEXTRACTPK="/tmp/.snmp/tls/private/rdk-snmpv3-snmpd-xpki-v1.key"
XPKIEXTRACTLC="/tmp/.snmp/tls/certs/rdk-snmpv3-snmpd-xpki-v1.pem"
RDKCALC="/etc/ssl/certs/snmp/tls/certs/rdkv-snmpdY22.crt"
SNMPDCONF="/tmp/.snmp/tls/certs/snmpd_v3.conf"
PRIORITY=10

EXPIRE_ONEDAY=$((24*60*60))

echo_t() {
    echo "$@" >> $SNMPDCONF
}

Extractpkcs12()
{
     mkdir -p /tmp/.snmp/tls/certs
     mkdir -p /tmp/.snmp/tls/support

     if [ -f $CONFIG_FILE ]; then
         $CONFIG_FILE $CFG_IN
         if [ -f $CFG_IN ]; then
             openssl pkcs12 -nodes -password pass:$(cat $CFG_IN) -in $STATIC_CERT -out $XPKIEXTRACT
             sed -n '/--BEGIN PRIVATE KEY--/,/--END PRIVATE KEY--/p; /--END PRIVATE KEY--/q' $XPKIEXTRACT  > $XPKIEXTRACTPK
             sed -n '/--BEGIN CERTIFICATE--/,/--END CERTIFICATE--/p; /--END CERTIFICATE--/q' $XPKIEXTRACT  > $XPKIEXTRACTLC
             chmod 600 $XPKIEXTRACTPK
             chmod 644 $XPKIEXTRACTLC
             rm -f $CFG_IN
         else
             echo "$CFG_IN not available"
         fi
     else
         echo "No $CONFIG_FILE to fetch $CFG_IN"
     fi
}

SnmpCertCheckandConfig()
{
    if [ -f $RDKCALC ]; then
        openssl x509 -checkend $EXPIRE_ONEDAY -noout -in $RDKCALC
        isCertExpiring=$?
        if [ "$isCertExpiring" != "1" ]; then
            echo_t "[snmp] localcert $(basename $RDKCALC)"
            #to support existing functionality, once cert expired this entry will not be added to conf file.
            echo_t "certSecName $PRIORITY rdk-managerY22.crt --cn"
            #we are adding verification based on root cert
            let "PRIORITY=$PRIORITY+1"
            echo_t "certSecName $PRIORITY RDK-SNMPV3-CA.crt --cn"
            echo_t "rwuser -s tsm \"RDK-SNMPV3-NMSy20\" auth .1"
        fi
    fi

    if [ -f $XPKIEXTRACTLC ]; then
        openssl x509 -checkend $EXPIRE_ONEDAY -noout -in $XPKIEXTRACTLC
        isCertExpiring=$?
        if [ "$isCertExpiring" != "1" ]; then
            echo_t ""
            echo_t "[snmp] localcert $(basename $XPKIEXTRACTLC)"
            let "PRIORITY=$PRIORITY+1"
            echo_t "certSecName $PRIORITY prod-root-xpki-ca.pem --cn"
            echo_t "rwuser -s tsm \"rdk-snmpv3-nms.xcal.tv\" auth .1"
        fi
    fi
}

if [ -d /etc/snmpv3/certs ]; then
     mkdir -p /tmp/.snmp/tls/private
     #Extract leaf cert from pkcs12 format
     Extractpkcs12

     #update snmpd_v3.conf based on expiry of leaf certificates to make sure that agent never sends expired certs to managers
     SnmpCertCheckandConfig

     #incase dynamic updation of config fails, copy backup configuration file.
     if [ ! -f $SNMPDCONF ]; then
         cp /etc/snmpv3/certs/snmpd_v3.conf $SNMPDCONF
     fi

     if [ -f /usr/bin/GetConfigFile ]; then
         GetConfigFile /tmp/.snmp/tls/private/rdkv-snmpd.key
         if [ -f /tmp/.snmp/tls/private/rdkv-snmpd.key ]; then
             chmod 600 /tmp/.snmp/tls/private/rdkv-snmpd.key
             mv /tmp/.snmp/tls/private/rdkv-snmpd.key /tmp/.snmp/tls/private/rdkv-snmpdY22.key
             chmod 600 /tmp/.snmp/tls/private/rdkv-snmpdY22.key
         fi
     else
         echo "GetConfigFile not Found !!"
         exit 127
     fi

     #execute c_rehash in ca-certs folder to get hash files for CA-chain
#     echo "c_rehash in ca-certs folder to get hash files for CA-chain"
#     c_rehash /etc/ssl/certs/snmp/tls/ca-certs/
fi
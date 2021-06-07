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
. /etc/device.properties


if [ -f /tmp/estb_ipv6 ];then
    echo "TLV_IP_MODE: IPv6 Mode..!"
    while [ ! -f /tmp/dibbler/client-duid ]
    do
        echo "Waiting for client duid generation"
        sleep 2
    done

    if [ -f /tmp/dibbler/client-duid ]; then
       cp /tmp/dibbler/client-duid /opt/dibbler/client-duid
    fi

    if [ ! -f /etc/os-release ];then
         if [ "$DEVICE_TYPE" = "hybrid" ] && [ "$BOX_TYPE" != "RNG150" ];then
             sh /lib/rdk/ipv4-client-upgrade.sh &
         fi
    fi

else
    echo "Box is in IPv4 Mode: Quitting the dibbler execution..!"
fi

exit 0

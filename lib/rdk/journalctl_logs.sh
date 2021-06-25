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


#Kill all background process
trap 'jobs -p | xargs kill' EXIT
. /etc/device.properties

OPTIONS=""
UNITS=""
OTHERS=""
XRE_UNITS=""

while [ "${1}" ];
do
    case "$1" in
    --options)
        OPTIONS="$2"
        shift 2
        ;;
    --units|-u)
        if [ "$2" = "xre-receiver" ] ||  [ "$2" = "xre-receiver.service" ] ;then
            XRE_UNITS="$XRE_UNITS -u $2"
        else
            UNITS="$UNITS -u $2"
        fi
        shift 2
        ;;
    *)
        OTHERS="$OTHERS $1"
        shift 1
        #break
        ;;
    esac
done
echo "OPTIONS = $OPTIONS"
echo "UNITS = $UNITS"
echo "OTHERS = $OTHERS"
echo "XRE_UNITS = $XRE_UNITS"

if [ "$CONTAINER_SUPPORT" == "true" ] && [ ! -f /opt/lxc_service_disabled ];then
    if [ "X" != "X$UNITS" ];then
        echo "cmd = journalctl $OTHERS $OPTIONS  $UNITS& "
        journalctl $OTHERS $OPTIONS  $UNITS&
    fi

    if [ "X" != "X$XRE_UNITS" ];then
        echo "cmd = journalctl $OTHERS $OPTIONS $XRE_UNITS -D /proc/$(lxc-info -n xre -p -H -P /lxc)/root/run/log/journal"
        journalctl $OTHERS $OPTIONS  $XRE_UNITS -D /proc/$(lxc-info -n xre -p -H -P /lxc)/root/run/log/journal
    fi

else
    echo "cmd = journalctl $OTHERS $OPTIONS $UNITS $XRE_UNITS"
    journalctl $OTHERS $OPTIONS $UNITS $XRE_UNITS
fi


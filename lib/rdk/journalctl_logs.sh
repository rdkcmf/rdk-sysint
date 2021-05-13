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


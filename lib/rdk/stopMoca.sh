#!/bin/sh

. /etc/device.properties

TR181_BIN="/usr/bin/tr181"
TR181_DISABLEMOCA_NAME="Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.DisableMoca.Enable"
MOCA_BIN="/usr/bin/rmh"
echo "triggered stopMoca.sh"
disableMoca="false"
if [ -f "$TR181_BIN" ]; then
        disableMoca=`$TR181_BIN -g $TR181_DISABLEMOCA_NAME  2>&1 > /dev/null`
fi

if [ "$disableMoca" != "true" ] ; then
        $MOCA_BIN stop
fi

/sbin/ip addr flush dev ${MOCA_INTERFACE}:0
/sbin/ip link set dev ${MOCA_INTERFACE}:0 down
/lib/rdk/zcip.script deconfig
exit 0
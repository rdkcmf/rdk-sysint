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

. /etc/device.properties

ZRAM_RFC_ENABLE=`/usr/bin/tr181Set -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.MEMSWAP.Enable 2>&1 > /dev/null`

if [ "x$ZRAM_RFC_ENABLE" != "xtrue" ]; then
    echo "zram is disabled"
    exit 1
fi

# load module
NRDEVICES=$(grep -c ^processor /proc/cpuinfo | sed 's/^0$/1/')
if modinfo zram | grep -q ' zram_num_devices:' 2>/dev/null; then
    MODPROBE_ARGS="zram_num_devices=${NRDEVICES}"
elif modinfo zram | grep -q ' num_devices:' 2>/dev/null; then
    MODPROBE_ARGS="num_devices=${NRDEVICES}"
else
    exit 1
fi
modprobe zram $MODPROBE_ARGS

# decide max percentage
max_percentage=50
if [ ! -z ${ZRAM_MEM_MAX_PERCENTAGE+x} ]; then
    echo "using max mem percentage from device.properties: $ZRAM_MEM_MAX_PERCENTAGE"
    max_percentage=${ZRAM_MEM_MAX_PERCENTAGE}
fi

# Calculate memory to use for zram (1/2 of ram)
totalmem=`LC_ALL=C free | grep -e "^Mem:" | sed -e 's/^Mem: *//' -e 's/  *.*//'`
mem=$(((totalmem * 1024 * ${max_percentage} ) / 100 / ${NRDEVICES}))

echo "enabling zram with $NRDEVICES devices of $mem size each"
echo "zram_enabled_stats: $NRDEVICES,$mem"
# give enough time for module loading to finish even under high load conditions.
sleep 3

# initialize the devices
for i in $(seq ${NRDEVICES}); do
    DEVNUMBER=$((i - 1))
    echo $mem > /sys/block/zram${DEVNUMBER}/disksize
    mkswap /dev/zram${DEVNUMBER}
    swapon -p 5 /dev/zram${DEVNUMBER}
done

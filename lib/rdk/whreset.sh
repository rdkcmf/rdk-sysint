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
if [ "$WHITEBOX_ENABLED" == "true" ]; then
    . /etc/wbdevice.conf
else
    wbpath=/opt/www/whitebox/
fi

. /etc/authService.conf

# clear wbdevice.dat and other data cleared in Rset
rm $aspath/deviceid.dat $wbpath/wbdevice.dat /opt/logger.conf /opt/hosts /opt/receiver.conf /opt/proxy.conf /opt/mpeenv.ini /tmp/mnt/diska3/persistent/hostData1

# execute all scripts invoked during a warehouse reset
cd /HrvInitScripts
sh clear_cached_unbound_ocap_apps.sh
sh clear_registered_libraries.sh
sh clear_persistent_dvb_storage.sh
sh clear_security_element_values_passed.sh
sh clear_persistent_generic_feature_params.sh
sh clear_xre_contents.sh
sh clear_persistent_host_memory.sh

sh /rebootNow.sh -s WarehouseReset -o "Rebooting the box after Warehouse Reset..."

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


. /etc/device.properties
. /etc/include.properties

if [ "$WHITEBOX_ENABLED" == "true" ]; then
     . /etc/wbdevice.conf
else
     wbpath=/opt/www/whitebox
fi

. /etc/authService.conf

executeScript()
{
   runScript=$1
   if [ -f $runScript ]; then
        sh $runScript
   else
        echo "Missing $runScript cleanup script..!"
   fi
}

if [ -f $aspath/deviceid.dat ] || [ -f $wbpath/wbdevice.dat ] ; then
    echo "Device is provisioned, leave si cache alone"
else
    echo "Device is not provisioned, safe to clear si cache"
    echo "Cleanup the SI cache"
    if [ "$DEVICE_TYPE" != "mediaclient" ]; then
        if [ -d /HrvInitScripts ]; then
            executeScript /HrvInitScripts/clear_xre_contents.sh
            executeScript /HrvInitScripts/clear_persistent_generic_feature_params.sh
            executeScript /HrvInitScripts/clear_persistent_dvb_storage.sh
            executeScript /HrvInitScripts/clear_cached_unbound_ocap_apps.sh
            executeScript /HrvInitScripts/clear_registered_libraries.sh
            executeScript /HrvInitScripts/clear_persistent_host_memory.sh
            executeScript /HrvInitScripts/clear_security_element_values_passed.sh
        else
            echo "Missing the HRV Inits scripts folder..!"
        fi
    else
        if [ -f $RDK_PATH/warehouse_reset.sh ]; then
            sh $RDK_PATH/warehouse_reset.sh
        else
            echo "Missing $RDK_PATH/warehouse_reset.sh cleanup script..!"
        fi
    fi
fi


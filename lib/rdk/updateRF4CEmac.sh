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


retry_cnt=0
max_retry_cnt=6
retry_delay=10
rf4ce_cache_file=/tmp/.rf4ce_mac
device_cache_file=/tmp/.deviceDetails.cache
rf4ce_log_file=/opt/logs/rf4ce_log.txt

if [ "x$RF4CE_CAPABLE" != "xtrue" ]; then
    echo "[$0] RF4CE is not supported" >> $rf4ce_log_file
    exit 0
fi

if [ -f $device_cache_file ]; then
    rf4ce_mac=`cat $device_cache_file | grep "rf4ce_mac" | cut -d "=" -f2`
    if [ `echo $rf4ce_mac | egrep "^([0-9A-F]{2}:){7}[0-9A-F]{2}$"` ]; then
        echo "[$0] RF4CE MAC is valid = $rf4ce_mac" >> $rf4ce_log_file
        echo "[$0] RF4CE mac retry count = $retry_cnt" >> $rf4ce_log_file
        exit 0    
    fi
fi

while [ $retry_cnt -le $max_retry_cnt ]; do
    sh $RDK_PATH/getDeviceDetails.sh refresh rf4ce_mac
    if [ -f $device_cache_file ]; then
        rf4ce_mac=`cat $device_cache_file | grep "rf4ce_mac" | cut -d "=" -f2`
        if [ `echo $rf4ce_mac | egrep "^([0-9A-F]{2}:){7}[0-9A-F]{2}$"` ]; then
            echo "[$0] RF4CE MAC is valid = $rf4ce_mac" >> $rf4ce_log_file
            exit 0    
        fi
    fi
    echo "[$0] RF4CE mac retry count = $retry_cnt" >> $rf4ce_log_file
    retry_cnt=`expr $retry_cnt + 1`
    sleep $retry_delay
done
echo "$[0] Unable to get Valid RF4CE mac address" >> $rf4ce_log_file

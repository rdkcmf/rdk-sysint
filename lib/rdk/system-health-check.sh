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

##############################################################################
## Script to check system health periodically and report to splunk instantly if
## a critical failure is detected.
##
## NOTE - This script is available only for eMMC devices now
##############################################################################

SPLUNK_ALERT_SCRIPT="/lib/rdk/alertSystem.sh"
RO_MNT_FLAG="/tmp/.ro_mnt_reported"

#Usage: uploadToSplunk <Process Name> <Alert Message>
uploadToSplunk()
{
    if [ -f $SPLUNK_ALERT_SCRIPT ]; then
        $SPLUNK_ALERT_SCRIPT "$1" "$2"
        if [ "$?" -eq "0" ]; then
            echo "Upload to splunk success"
            return 0
        else
            echo "Upload to splunk failed"
        fi
    else
        echo "Alert script not found. Not reporting to splunk"
    fi
    return 1
}


# Check for read-only mmc partitions
ro_mmc_part=$(awk '$1 ~ "mmcblk" { if(substr($4,1,2) == "ro") print $1 }' /proc/mounts | sort | uniq)

if [ -n "$ro_mmc_part" ]; then
    echo "Read only mmc partitions detected. Report to splunk immediately"
    if [ ! -f "$RO_MNT_FLAG" ]; then
        uploadToSplunk "mount" "Read-only nvram detected for $ro_mmc_part"
        if [ "$?" -eq "0" ]; then
            touch "$RO_MNT_FLAG"
        fi
    else
        echo "Read only mmc partitions already reported to splunk"
    fi
fi

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

PARODUS_LOG="/opt/logs/parodus.log"
PREVIOUS_REBOOT_INFO_FILE="/opt/secure/reboot/previousreboot.info"

parodusLog() {
    timestamp=`/bin/timestamp`
    echo "$timestamp $0: $*" >> $PARODUS_LOG
}
parodusLog "Start Execution"
if [ -f $PREVIOUS_REBOOT_INFO_FILE ]; then
    timestamp=`grep -w "timestamp" $PREVIOUS_REBOOT_INFO_FILE | awk -F '"' '{print $4}'`
    reboot_reason=`grep -w "reason" $PREVIOUS_REBOOT_INFO_FILE | awk -F '"' '{print $4}'`
    customReason=`grep -w "customReason" $PREVIOUS_REBOOT_INFO_FILE | awk -F '"' '{print $4}'`
    source=`grep -w "source" $PREVIOUS_REBOOT_INFO_FILE | awk -F '"' '{print $4}'`
    parodusLog "PreviousRebootInfo:$timestamp,$reboot_reason,$customReason,$source"
else
    parodusLog "File $PREVIOUS_REBOOT_INFO_FILE not found, failed to get the Previous Reboot Info"
fi
parodusLog "End Execution"

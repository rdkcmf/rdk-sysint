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
##################################################################
## Script to do Device Initiated Tr69 Firmware Download
##  * Flash image 
##  * Check for bin file
##  * Flash image
##  * Call reboot script
##################################################################

if [ -f /etc/device.properties ];then
     . /etc/device.properties
fi

# override env if RFC desires
. $RDK_PATH/rfcOverrides.sh

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/bin:/lib:/usr/lib:/usr/local/lib:/mnt/nfs/bin
Imagename=$DIFW_PATH/*.bin
FLASH_FILE_NAME="/opt/cdl_flashed_file_name"
image=`ls $DIFW_PATH/*.bin`
UPGRADE_FILE=`echo ${image##*/}`

#Use log framework to pring timestamp and source script name
swupdateLog()
{
    echo "`/bin/timestamp`: $0: $*"
}

echo $Imagename
if [ "$Imagename" = "" ]; then
    swupdateLog "Image file name is empty.\n"
    exit -1
fi

if [ -f /lib/rdk/imageFlasher.sh ]; then
     sh /lib/rdk/imageFlasher.sh "tr69" "$DIFW_PATH" "$UPGRADE_FILE"
else
     swupdateLog "Ensure the platform flashing utility..!"
fi

swupdateLog "Waiting for the image flash completion..!"
sleep 120
swupdateLog "Completing the image flash wait..!"
echo "$flashState" | grep -i 'failed' >  /dev/null
if [ $? -ne 0 ]; then
    sync
    echo "$UPGRADE_FILE" > $FLASH_FILE_NAME
    swupdateLog "CDL download is complete, Rebooting the box now\n"
    rm -rf  /opt/.gstreamer
    exit 0
else
    rm -rf $Imagename
    exit $?
fi

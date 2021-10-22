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

set -x

server="rdk4apps.com"
sourcepath="https://rdk4apps.com:8055/Images"
imagePath="/tmp/images"
rebootDelay=120
DNLD_STATUS_FILE="/tmp/.dwnldStatus"
DWNLD_LOG_FILE="/tmp/dwnldlog.txt"

export PATH=$PATH:/usr/local/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
export SSL_CERT_FILE=/etc/ssl/certs/qt-cacert.pem

swupdateLog ()
{
    echo "`/bin/timestamp` : $*" >> $DWNLD_LOG_FILE
}

# creating working path
mkdir -p $imagePath
# move to the working path
cd $imagePath
swupdateLog "--- Download method called ----"
swupdateLog "Pulling image $1.img from server $server"
swupdateLog "calling curl -o $imagePath/$1 $sourcepath/$1"

# image download
curl -o $imagePath/$1 $sourcepath/$1
if [ $? -ne 0 ]; then
    swupdateLog "Can not pull image from server quitting"
    echo "failed" > /tmp/.dwnld
fi

swupdateLog "now flashing image $1" 

# invoking device specific call to flash the image
swupdateLog "sh  /lib/rdk/imageFlasher.sh "HTTP" $sourcepath $imagePath $1"
sh  /lib/rdk/imageFlasher.sh "HTTP" $sourcepath $imagePath $1
if [ $? -eq 0 ] ; then
    swupdateLog "======= Success flashing image... box will reboot in $rebootDelay seconds =============="
    echo "success" > $DNLD_STATUS_FILE
    sleep $rebootDelay
    /rebootNow.sh -s ImageUpgrade_"`basename $0`" -o "Rebooting the box after Image Upgrade..."
else
    swupdateLog "======= Can not flash image... may be its a bad one  =============="
    echo "failed" > $DNLD_STATUS_FILE
    exit 1
fi
exit 0


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

export PATH=$PATH:/usr/local/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
export SSL_CERT_FILE=/etc/ssl/certs/qt-cacert.pem

# creating working path
mkdir -p $imagePath
# move to the working path
cd $imagePath
echo "--- Download method called ----" > /tmp/dwnldlog.txt
echo Pulling image $1.img from server $server >> /tmp/dwnldlog.txt
echo calling curl -o $imagePath/$1 $sourcepath/$1 >> /tmp/dwnldlog.txt
# image download
#scp  -i /etc/dropbear/dropbear_rsa_host_key rdkcl@$server:/opt/images/$1 .
curl -o $imagePath/$1 $sourcepath/$1
if [ $? -ne 0 ]; then
  echo "Can not pull image from server quitting" >> /tmp/dwnldlog.txt
  echo "failed" > /tmp/.dwnld
fi
#sync
echo "now flashing image $1" 
echo "now flashing image $1" >> /tmp/dwnldlog.txt
# invoking device specific call to flash the image
echo sh  /lib/rdk/imageFlasher.sh "HTTP" $sourcepath $imagePath $1 >> /tmp/dwnldlog.txt
sh  /lib/rdk/imageFlasher.sh "HTTP" $sourcepath $imagePath $1 >> /tmp/dwnldlog.txt
if [ $? -eq 0 ] ; then
  echo "======= Success flashing image... box will reboot in $rebootDelay seconds ==============" >> /tmp/dwnldlog.txt
  echo "success" > $DNLD_STATUS_FILE
  sleep $rebootDelay
  #reboot
  /rebootNow.sh -s ImageUpgrade_"`basename $0`" -o "Rebooting the box after Image Upgrade..."
else
  echo "======= Can not flash image... may be its a bad one  ==============" >> /tmp/dwnldlog.txt
  echo "failed" > $DNLD_STATUS_FILE
  exit 1
fi
exit 0


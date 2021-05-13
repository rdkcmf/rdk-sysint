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


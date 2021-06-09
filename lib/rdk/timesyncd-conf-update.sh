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

sleep_time=5
output=""
count=0

# Ensure auth service is ready for URL request
auth_pid=`pidof authservice`
while [ ! $auth_pid ]
do
     sleep 5
     auth_pid=`pidof authservice`
done
echo "Auth service ready now..!"
sleep 2
# NTP URL from the property file
if [ -f /lib/rdk/getPartnerProperty.sh ]; then
     hostName=`/lib/rdk/getPartnerProperty.sh ntpHost`
fi

while [ ! "$hostName" ]
do

    if [ -f /lib/rdk/getPartnerProperty.sh ]; then
         hostName=`/lib/rdk/getPartnerProperty.sh ntpHost`
    fi

   sleep 5
done
echo "NTP Server URL for this env is $hostName ..!"

# Update the timesyncd configuration with URL
if [ -f /etc/systemd/timesyncd.conf ];then
      defaultHostName=`cat /etc/systemd/timesyncd.conf | grep ^NTP= | cut -d "=" -f2 | tr -s ' '`
      if [ "$hostName" ] && [ "$hostName" != "$defaultHostName" ];then
           # Update the timesyncd configuration with URL
           cp /etc/systemd/timesyncd.conf /tmp/timesyncd.conf
           sed -i "s/^NTP=$defaultHostName/NTP=$hostName $defaultHostName/" /tmp/timesyncd.conf
           echo "ConnectionRetrySec=5" >> /tmp/timesyncd.conf
           cat /tmp/timesyncd.conf > /etc/systemd/timesyncd.conf
           rm -rf /tmp/timesyncd.conf
           # Restart the service to reflect the new conf
           echo "`date`: Restarting the service: systemd-timesyncd.service ..!"
           /bin/systemctl restart systemd-timesyncd.service
      else
           echo "Hostnames are same ($hostName, $defaultHostName)"
      fi
else
      echo "Missing configuration file: /etc/systemd/timesyncd.conf"
fi

exit 0

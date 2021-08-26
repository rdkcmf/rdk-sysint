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


sleep_time=5
output=""
count=0

if [ -f /etc/env_setup.sh ]; then
    . /etc/env_setup.sh
fi

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
           /bin/systemctl reset-failed systemd-timesyncd.service
           /bin/systemctl restart systemd-timesyncd.service
      else
           echo "Hostnames are same ($hostName, $defaultHostName)"
      fi
else
      echo "Missing configuration file: /etc/systemd/timesyncd.conf"
fi

exit 0

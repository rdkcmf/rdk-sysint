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
. /etc/env_setup.sh

sleep_time=5
output=""
count=0

if [ -z "$DEFAULT_DATE" ]; then
       echo "`/bin/timestamp` DEFAULT_DATE not set in device.properties"
       DEFAULT_DATE=20140101
fi

# Check for the partner ID
curl -d '' -X POST http://127.0.0.1:50050/authService/getDeviceId >/tmp/ntp.txt
output=`awk -F',' </tmp/ntp.txt '{ for (i=1; i<=NF; i++) print $i}'| grep partnerId | cut -d ":" -f2 | tr -d " " |sed -e 's/[{,},/"]//g'`
partnerName=`echo "$output" | tr '[A-Z]' '[a-z]'`

echo $output $partnerName

# Cox network code
if [ "$partnerName" = "cox" ]; then
    if [ -f /lib/rdk/getPartnerProperty.sh ]; then
         hostName=`/lib/rdk/getPartnerProperty.sh ntpHost`
    fi
else
    if [ "$BUILD_TYPE" = "dev" -a "$KICKSTART" != "yes" ]; then
            hostName=10.252.216.12
    else
        if [ "$partnerName" = "comcast" ]; then
            if [ -f /lib/rdk/getPartnerProperty.sh ]; then
                 hostName=`/lib/rdk/getPartnerProperty.sh ntpHost`
            fi
        else
            hostName=ntp01.cmc.co.denver.comcast.net
        fi
    fi
fi

while true
do
        output=`pidof ntpd`
        if [ ! "$output" ]; then
                ntpd -p "$hostName" -S /lib/rdk/ntpCheck.sh
        fi
        current_date=`date +%Y%m%d`
        if [ $count -eq 0 ]; then
                if [ $current_date -gt $DEFAULT_DATE ]; then
                        echo "`/bin/timestamp` NTP Service started successfully "
                        sleep_time=300
                        count=1
                else
                        echo "`/bin/timestamp` NTP date is not synced "
                fi
        fi
        sleep $sleep_time
done


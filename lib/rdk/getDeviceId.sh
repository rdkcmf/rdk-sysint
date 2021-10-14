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

. /etc/include.properties
. /etc/device.properties
BSFILE='/opt/secure/RFC/bootstrap.ini'
FILENAME='/tmp/.bootstrap.ini'

deviceIdFile="/opt/www/authService/deviceid.dat"
partnerIdFile="/opt/www/authService/partnerId3.dat"
wbDeviceIdFile="/opt/www/whitebox/wbdevice.dat"

if [ "$DEVICE_NAME" = "PLATCO" ]; then
	defaultPartnerId="xglobal"
else
	defaultPartnerId="comcast"
fi

deviceId=""
partnerId=""

getBootstrapPartnerId()
{
    if [ -f "$BSFILE" ]; then

        cp $BSFILE $FILENAME
        sed -i 's/=/ /g' $FILENAME #

        while read line
        do

            ## Check bootstrap string

            value1=`echo "$line" | awk '{print $1}'`
            value2=`echo "$line" | awk '{print $2}'`

            enable_Check=`echo "$value1" | grep -ci 'X_RDKCENTRAL-COM_Syndication.PartnerId'`

            if [ $enable_Check -ne 0 ]; then
                echo "$value2"

                return
            fi
        #
        done < $FILENAME
    fi

### Nothing found in the boostrap file
    echo ""
}


if [ -f "${deviceIdFile}" ]; then
    deviceId=`cat ${deviceIdFile}`
elif [ -f "${wbDeviceIdFile}" ]; then
    deviceId=`cat "${wbDeviceIdFile}"`
fi

if [ -f "${partnerIdFile}" ]; then
    partnerId=`cat ${partnerIdFile}`
else
	# Check if bootstrap was updated with partnerId
	partnerId=$(getBootstrapPartnerId)
	if [ "$partnerId" = "" ]; then
	    # If boostrap partnerId is missing, use default id based on device class
		if [ "x${deviceId}" != "x" ]; then
			partnerId=${defaultPartnerId}
		fi
	fi
fi

echo "{ \"deviceId\" : \"${deviceId}\", \"partnerId\" : \"${partnerId}\" }"
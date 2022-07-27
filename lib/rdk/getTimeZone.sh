#!/bin/sh
##
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2020 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http:##www.apache.org#licenses#LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##

. /etc/device.properties

timeZoneDSTPath="/opt/persistent/timeZoneDST"
timeZoneOffsetMap="/etc/timeZone_offset_map"
timeZone=""
timeZoneOffset=""
zoneValue=""

echo "`/bin/timestamp` Retrieving the timezone value"

if [ "$DEVICE_NAME" = "PLATCO" ]; then
   timeZone=`cat "$timeZoneDSTPath" | grep -v 'null'`

   if [ -z "$timeZone" ]; then
      echo "`/bin/timestamp` /opt/persistent/timeZoneDST is empty, default timezone America/New_York applied"
      timeZone="America/New_York"
   else
      echo "`/bin/timestamp` Device TimeZone: $timeZone"
   fi

   if [ -f "$timeZoneOffsetMap" -a -s "$timeZoneOffsetMap" ]; then
      zoneValue=`cat $timeZoneOffsetMap | grep $timeZone | cut -d ":" -f2 | sed 's/[\",]/ /g'`
      timeZoneOffset=`cat $timeZoneOffsetMap | grep $timeZone | cut -d ":" -f3 | sed 's/[\",]/ /g'`
   fi

   if [ -z "$zoneValue" -o -z "$timeZoneOffset" ]; then
      echo "`/bin/timestamp` Given TimeZone not supported by XConf - default timezone US/Eastern with offset 0 is applied"
      zoneValue="US/Eastern"
      timeZoneOffset="0"
   fi

   echo "`/bin/timestamp` TimeZone Information after mapping : zoneValue = $zoneValue, timeZoneOffset = $timeZoneOffset"
else
   if [ "x$ENABLE_MAINTENANCE" != "xtrue" ]; then
      JSONPATH=/opt
      if [ "$CPU_ARCH" == "x86" ]; then JSONPATH=/tmp; fi
      echo "Reading Timezone value from $JSONPATH/output.json file..."

      counter=1
      while [ ! "$zoneValue" ]
      do
         echo "timezone retry:$counter"
         if [ -f $JSONPATH/output.json ] && [ -s $JSONPATH/output.json ];then
            grep timezone $JSONPATH/output.json | cut -d ":" -f2 | sed 's/[\",]/ /g' > /tmp/.timeZone.txt
         fi

         while read entry
         do
            zoneValue=`echo $entry | grep -v 'null'`
            if [ ! -z "$zoneValue" ]; then
               break
            fi
         done < /tmp/.timeZone.txt

         if [ $counter -eq 10 ];then
            echo "Timezone retry count reached the limit . Timezone data source is missing"
            break;
         fi

         counter=`expr $counter + 1`
         sleep 6
      done

      if [ -n "$zoneValue" ]; then
         echo "Got timezone using $JSONPATH/output.json successfully, value:$zoneValue"
      else
         echo "Timezone value from $JSONPATH/output.json is empty"
      fi
   fi

   if [ -z "$zoneValue" ]; then
      if [ -f "$timeZoneDSTPath" -a -s "$timeZoneDSTPath" ]; then
         zoneValue=`cat "$timeZoneDSTPath" | grep -v 'null'`
         echo "Got timezone using $timeZoneDSTPath successfully, value:$zoneValue"
      else
         echo "$timeZoneDSTPath file not found, Timezone data source is missing"
      fi
   fi
fi

echo "$zoneValue"

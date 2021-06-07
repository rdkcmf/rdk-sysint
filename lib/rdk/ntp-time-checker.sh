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

x=1

while [ $x -ne 5 ]
do
   x=`expr $x + 1`
   if [ -f /tmp/clock-event ] || [ -f /run/systemd/timesync/synchronized ];then
        x=5        
   fi
   echo "NTP Time not set yet..!"
   sleep 60
done

echo "NTP Event set using the build time..!"
touch /tmp/clock-event
if [ -d /run/systemd/timesync ];then
    touch /run/systemd/timesync/synchronized
fi
exit 0

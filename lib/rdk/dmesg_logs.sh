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

# Save boot log
dmesg > /opt/logs/startup_stdout_log.txt

# Start syslog server
syslogd -O /opt/logs/messages.txt

# Send dmesg to syslog (per Comcast BPV-53) 
klogd

while [ 1 ]; do
   if [ "$LIGHTSLEEP_ENABLE" = "true" ];then
         if [ -f /tmp/.power_on ];then
              dmesg -c >> /opt/logs/messages-dmesg.txt
         fi
   else
         dmesg -c >> /opt/logs/messages-dmesg.txt
   fi
   sleep 5
done


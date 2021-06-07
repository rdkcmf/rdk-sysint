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

if [ ! -f /etc/os-release ];then
    # exit if an instance is already running
    if [ ! -f /tmp/.dmesg-logger.pid ];then
        # store the PID
        echo $$ > /tmp/.dmesg-logger.pid
    else
        pid=`cat /tmp/.dmesg-logger.pid`
        if [ -d /proc/$pid ];then
            exit 0
        fi
    fi
fi

if [ "$LIGHTSLEEP_ENABLE" = "true" ];then
     if [ -f /tmp/.power_on ];then
          date >> /opt/logs/messages-dmesg.txt
     fi
else
     date >> /opt/logs/messages-dmesg.txt
fi

# PID file cleanup
if [ ! -f /etc/os-release ] && [ -f /tmp/.dmesg-logger.pid ];then
    rm -rf /tmp/.dmesg-logger.pid
fi

exit 0


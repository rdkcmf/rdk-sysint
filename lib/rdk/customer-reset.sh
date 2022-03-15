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
   
# persistent data cleanup
if [ -d /opt/persistent ]; then
    find /opt/persistent -mindepth 1 -maxdepth 1 ! -name 'store-mode-video' -exec rm -rf {} \;
fi
rm -rf /opt/secure/persistent/rdkservicestore
if [ "$DEVICE_TYPE" = "mediaclient" ];then
     if [ -f /lib/rdk/ubi-volume-cleanup.sh ];then
         sh /lib/rdk/ubi-volume-cleanup.sh "PERSISTENT_jffs2"
     fi
     sleep 1
fi
# opt data cleanup
if [ -d /opt/logs ]; then
     rm -rf /opt/logs/*
fi
if [ -d /var/logs ]; then
     rm -rf /var/logs/*
fi

if [ "$DEVICE_TYPE" = "mediaclient" ];then
     if [ -f /lib/rdk/ubi-volume-cleanup.sh ];then
         sh /lib/rdk/ubi-volume-cleanup.sh "OPT_jffs2"
     fi
     sleep 1
fi

exit 0

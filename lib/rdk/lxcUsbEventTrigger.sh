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


counter=1
while [ ! `pidof Receiver` ]
do
    sleep 2
    counter=`expr $counter + 1`
    if [ $counter -eq 30 ];then break; fi
done
echo "`date`: `basename $0`: Receiver Process Started..!"  
# Time for Receiver QT Initialization
sleep 10
# Triggering kernel events for USB Input devices
for x in `find /sys -iname uevent |  grep usb | grep input`
do
   echo $x
   echo add > $x
done

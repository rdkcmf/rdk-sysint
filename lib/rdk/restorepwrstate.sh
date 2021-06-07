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

# Script to restore the power state before reboot 
# Please refer to PARKER-4473 for details
# first check if the config flag is set
flag=`cat /mnt/nfs/env/mpeenv.ini | grep "SAVE_POWERSTATE_ON_REBOOT" | cut -d "=" -f2`
#restore the power state if flag is TRUE; do nothing otherwise
if [ $flag == "TRUE" ]; then
  # check if the file existis
  if [ -f /opt/lastPowerState ] ; then
        str=`cat /opt/lastPowerState`
        echo $str
        /SetPowerState $str
        ret=`rm /opt/lastPowerState`
  fi
fi


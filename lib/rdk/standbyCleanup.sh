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


if [ ! -z $1 ] && [ $1 == "--forceShutdown" ];then
  echo "Forcing shutdown without checking RFC"
  /lib/rdk/shutdownReceiver.sh &
else
  _keepReceiverProcessOnStandby=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.KeepReceiverProcessOnStandby.Enable 2>&1 > /dev/null`
  if [ ! -z "$_keepReceiverProcessOnStandby" ]; then
    if [ -f /tmp/retainConnection ] && [[ $_keepReceiverProcessOnStandby == "true" ]]; then
      echo "RFC KeepReceiverProcessOnStandby defined and approved by XRE - Don't shutdown receiver process"
    else
      echo "RFC KeepReceiverProcessOnStandby is not true or RDK-22152 is not approved by XRE - shutdown receiver process"
      /lib/rdk/shutdownReceiver.sh &
    fi
  else
    echo "RFC KeepReceiverProcessOnStandby not defined - shutdown receiver process"
    /lib/rdk/shutdownReceiver.sh &
  fi
fi

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


sleepTime=10

originalReceiverPid=`pidof Receiver`

kill $originalReceiverPid

echo "sleeping for " . $sleepTime " seconds before checking if receiver restart was successful"
sleep $sleepTime 
echo "checking to see if the receiver restart was successful"


newReceiverPid=`pidof Receiver`

if [ "$originalReceiverPid" == "$newReceiverPid" ]
then
  echo "killing the receiver with -9"
  kill -9 $originalReceiverPid
else
  echo "receiver restart was successful on first try"
fi

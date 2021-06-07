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

if [ $# -ne 1 ]
then
  echo "Usage: setVpopEnabled.sh <true|false>"
  exit 1
fi

if [ $1 == "true" ]
then
  echo -e 't2p:msg\n{"setDLNAProperties" : {"dlnaEnabled": true\n}}\nt2p:msg' | nc localhost 3773
else
  echo -e 't2p:msg\n{"setDLNAProperties" : {"dlnaEnabled": false\n}}\nt2p:msg' | nc localhost 3773
fi


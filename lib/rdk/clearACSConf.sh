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
  echo "Usage: clearACSConf.sh <partner_id>"
  exit 1
fi

kill -9 `ps aux | grep -i start.sh | grep -v grep | awk '{print $2}'` &>/dev/null
kill -9 `ps aux | grep -i dimclient | grep -v grep | awk '{print $2}'` &>/dev/null

if [ -e /opt/tr69agent-db ]; then rm -rf /opt/tr69agent-db; fi
if [ -e /opt/secure/tr69agent-db ]; then rm -rf /opt/secure/tr69agent-db; fi
if [ -e /opt/persistent/tr69bootstrap.dat ]; then rm /opt/persistent/tr69bootstrap.dat; fi

#Restart tr69-agent service
systemctl restart tr69agent.service


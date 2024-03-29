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

if [ -f /etc/env_setup.sh ];then
	. /etc/env_setup.sh
fi

if [ -f /etc/os-release ];then
       exit 0
fi

PROCESS_PATH="/usr/bin"
PROCESS_NAME="sdvAgent"


if [ -f /opt/debug.ini ] && [ "$BUILD_TYPE" != "prod" ]; then
    debugConfigFile="/opt/debug.ini"
else
    debugConfigFile="/etc/debug.ini"
fi


restart_process()
{
  currDir=`pwd`
  cd $PROCESS_PATH
  if [ ! -f /etc/os-release ];then
      if [ -f ./$1 ]; then
          echo "`/bin/timestamp` Restarting the process $1"
          ./$1 --debugconfig $debugConfigFile &
          sleep 1
      fi
  else
      /bin/systemctl restart sdvagent.service
  fi
  cd $currDir
}

rebootFunction()
{
  echo "`/bin/timestamp` $1 process crashed Rebooting the box" >> /opt/logs/uimgr_log.txt
  echo "`/bin/timestamp` $1 process crashed Rebooting the box" >> /opt/logs/ocapri_log.txt
  sleep 1

  if [ -f /lib/rdk/debug_info.sh ]; then
       sh /lib/rdk/debug_info.sh >> /opt/logs/top_log.txt
  fi
  if [ -f /rebootNow.sh ]; then
       sh /rebootNow.sh -s SdvAgentRecovery -o "Rebooting the box due to $1 process crash..." &
  fi
}


loop=1
count=0
retries=10

while [ $loop -eq 1 ]
do
  ret=`ps | grep sdvAgent | grep -v grep| wc -l`
  if [ $ret -eq 0 ]; then
    if [ $count -lt $retries ]; then
      count=`expr $count + 1`
      restart_process  $PROCESS_NAME;
    else
      rebootFunction $PROCESS_NAME;
    fi
  else
    count=0
  fi

  sleep 30
done


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

if [ -f /etc/env_setup.sh ]; then
    . /etc/env_setup.sh
fi

LOG_FILE="/opt/logs/path_fail.log"

lsof_output=$(lsof)
ps_output=$(ps -ef)

echo "`date` Path failure notifier triggered for $1" >> $LOG_FILE

echo "$lsof_output" >> $LOG_FILE
echo "$ps_output" >> $LOG_FILE

echo "Max inotify instances `cat /proc/sys/fs/inotify/max_user_instances`" >> $LOG_FILE
cur_count=`echo "$lsof_output" | grep inotify | wc -l`
echo "current open inotify instances $cur_count" >> $LOG_FILE

sleep 5
systemctl restart $1

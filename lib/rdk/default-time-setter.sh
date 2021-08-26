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

if [ -f /tmp/date_completed ];then
     echo "BUILD TIME is already set previously..!"
     exit 0
fi
buildTime=`grep BUILD_TIME /version.txt | cut -d "=" -f2|sed -e 's/\"//g'`
if [ "$buildTime" ];then
     echo "Default Time Setup: $buildTime"
     date -s "$buildTime"
else
     date -s 2001.01.01-00:00:00
fi

touch /tmp/date_completed
exit 0

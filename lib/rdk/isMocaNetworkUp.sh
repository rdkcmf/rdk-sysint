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


#MoCA 2.0 supports mocap
if [ -f /usr/bin/mocap ]; then
  linkStatus=`mocap get --link | awk '{for (i=1;i<=NF;i++) if($i ~/link_status/) print $(i+2)}' |tr '[A-Z]' '[a-z]'`
else
  linkStatus=`mocactl show --status | grep linkStatus | sed 's/.*linkStatus.*:/\1/' | tr -d ' ' | tr '[A-Z]' '[a-z]'`
fi

#echo $linkStatus

if [ "$linkStatus" == "up" ]; then
  echo 1
else
  echo 0
fi


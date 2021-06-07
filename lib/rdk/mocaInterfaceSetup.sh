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


#==================================================================
# SCRIPT: mocaInterface.sh
# USAGE : mocaInterface.sh <interface name)
# DESCRIPTION: script to enable/disable moca interface for lightsleep
#==================================================================
interface=$1
flag=$2

if [ $flag -eq 1 ] ; then
     sh /lib/rdk/mocaSetup.sh 0 eth0 
else
     /etc/moca/net.moca stop
fi

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

### Adding support for named.log and dnsquery.log
if [ -f /tmp/.standby ];then
	exit 0
fi
if [ -f /var/cache/bind/named.log ];then
       cat /var/cache/bind/named.log >>/opt/logs/named.log
       : > /var/cache/bind/named.log
fi

if [ -f /var/cache/bind/querylog.txt ];then
       cat /var/cache/bind/querylog.txt >>/opt/logs/dnsquery.log
       : > /var/cache/bind/querylog.txt
fi


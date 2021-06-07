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

. /etc/env_setup.sh
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
if [ ! -f /tmp/gatewayConnected ]; then
	process=`ps | grep Receiver  | grep -v grep `             
	while [ "$process" = "" ]; 
	do
		sleep 10                                            
		echo "`/bin/timestamp` sleeping 10 sec for Receiver  "  >> $logsFile
	done

	touch /tmp/gatewayConnected
	echo "`/bin/timestamp` sending MoCA status event"
	if [ -f /usr/local/bin/IARM_event_sender ]; then
		/usr/local/bin/IARM_event_sender MocaStatusEvent 2
	fi

	if [ -f /usr/bin/IARM_event_sender ]; then
		/usr/bin/IARM_event_sender MocaStatusEvent 2
	fi
	process=`ps | grep tr69hostif  | grep -v grep `
	while [ "$process" = "" ];
	do
		sleep 15
		process=`ps | grep tr69hostif  | grep -v grep `
	done
	echo "`/bin/timestamp` sending gateway connected event"
	if [ -f /usr/local/bin/IARM_event_sender ]; then
		/usr/local/bin/IARM_event_sender GatewayConnEvent 1
	fi
	if [ -f /usr/bin/IARM_event_sender ]; then
		/usr/bin/IARM_event_sender GatewayConnEvent 1
	fi
fi

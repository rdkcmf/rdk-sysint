#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2016 RDK Management, LLC. All rights reserved.
# ============================================================================
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

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
. /etc/env_setup.sh

LOG_FILE=/opt/logs/top_log.txt
count=0

# XRE-11056: Added rdkbrowser2, WPE* and rtrmfplayer to the list of dumped processes for XI and XG.
if [ "$DEVICE_TYPE" = "mediaclient" ]; then
    if [ "$DEVICE_NAME" = "PLATCO" ]; then
        top_cmd="top -b -o +%CPU | head -n 17"
    else
        top_cmd="top | grep -E 'load|Tasks|Cpu|Mem|Swap|COMMAND|Receiver|uimgr_main|lighttpd|rmfStreamer|IARMDaemonMain|dsMgrMain|Main|nrdPluginApp|rdkbrowser2|rtrmfplayer|WPE|fogcli' | grep -vE 'grep|run.sh'"
    fi
elif [ "$DEVICE_TYPE" = "hybrid" ]; then
     top_cmd="top | grep -E 'load|Tasks|Cpu|Mem|Swap|COMMAND|rmfStreamer|Receiver|lighttpd|IARMDaemonMain|dsMgrMain|runPod|Main|nrdPluginApp|rdkbrowser2|rtrmfplayer|WPE|fogcli' | grep -vE 'grep|run.sh'"
else
     top_cmd="top | grep -E 'load|Tasks|Cpu|Mem|Swap|COMMAND|mpeos|Receiver|uimgr_main|lighttpd|IARMDaemonMain|dsMgrMain|Main|nrdPluginApp|fogcli' | grep -vE 'grep|run.sh'"
fi

# adding sleep of 180 sec to reduce high load condition during bootup
if [ ! -f /etc/os-release ]; then
    sleep 180
fi

# Adding the Clock Frequency Info
echo "Clock Frequency Info:"
cat /proc/cpuinfo | grep MH | sed 's/[[:blank:]]*//g'

# Logging to top_log.txt directly only for Legacy platforms.
# Making echo of all the logs so that it directly goes to journal buffer to support lightsleep on HDD enabled Yocto platforms.
if [ ! -f /etc/os-release ]; then
	echo "Logging for Non-yocto platforms..."
	while true
	do
		echo "`/bin/timestamp`"
                uptime
		eval $top_cmd
                echo "********** Disk Space Usage **********"
		echo "`/bin/df -h`"
		count=`expr $count + 1`
                if [ ! -f /tmp/.standby ];then
	             if [ -f /lib/rdk/heap-usage-stats.sh ];then
                         sh /lib/rdk/heap-usage-stats.sh >> $LOG_PATH/messages.txt
                     fi
	             if [ -f /lib/rdk/cpu-statistics.sh ];then
                         sh /lib/rdk/cpu-statistics.sh >> $LOG_FILE 
                     fi
                else
	             if [ -f /lib/rdk/cpu-statistics.sh ];then
                         sh /lib/rdk/cpu-statistics.sh >> $LOG_FILE
                     fi
                fi
		sleep $1
		if [ $count -eq 12 ]; then
       			top -b -n1
       			count=0
  		fi
	done
else
	echo "Logging for Yocto platforms..."
	echo "`/bin/timestamp`"
        uptime
	eval $top_cmd
	echo "********** Disk Space Usage **********"
	echo "`/bin/df -h`"
        if [ ! -f /tmp/.standby ];then
            if [ -f /lib/rdk/heap-usage-stats.sh ];then
                 sh /lib/rdk/heap-usage-stats.sh >> $LOG_PATH/messages.txt
            fi
        fi
	if [ -f /lib/rdk/cpu-statistics.sh ];then
              sh /lib/rdk/cpu-statistics.sh
        fi
	if [ -f /tmp/.top_count ]; then
		curr_count=`cat /tmp/.top_count`
		count=`expr ${curr_count} + 1`
		if [ $count -eq 6 ]; then
			top -b -n1 | grep -vE 'grep|run.sh'
                        cat /proc/meminfo
			count=0
		fi
	fi
	echo "$count" > /tmp/.top_count
fi


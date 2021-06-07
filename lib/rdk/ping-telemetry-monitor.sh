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


ping_command="ping"
[ -f /tmp/estb_ipv6 ] && ping_command="ping6"
ping_max_allowed_cpu=0.5
ping_monitor_file="/tmp/ping_cpu_monitor"
# Function to kill currently running ping test, creates flag to indicate that ping is to be restarted
restart_ping_with_higher_interval () {
    ping_pid=`pidof $ping_command`
    echo "`timestamp` PingMonitor:Stopping current ping test"
    kill -9 $ping_pid
    if [ $? -eq 0 ]; then
        echo "`timestamp` PingMonitor:Creating ping restart flag"
        touch /tmp/ping_restart
    fi
}

# Function to monitor cpu usage of ping test
# If usage is greater than 1%, then ping needs to be restarted with doubled interval
monitor_cpu () {
    echo "`timestamp` PingMonitor:Starting ping monitor"
    while [ -f $ping_monitor_file ]
    do
        ping_pid=`pidof $ping_command`
        while [ "$ping_pid" == "" ]; do
            sleep 1
            if [ ! -f $ping_monitor_file ]; then
                exit 0
            fi
            ping_pid=`pidof $ping_command`
        done

        ping_cpu_usage=`ps -p $ping_pid -o %cpu | grep -v "CPU" | head -n 1 | sed 's/^ //g'`
        if (( $(awk 'BEGIN {print ("'$ping_cpu_usage'" >= "'$ping_max_allowed_cpu'")}') )); then
            echo "`timestamp` PingMonitor:CPU usage exceeded the limit : $ping_cpu_usage"
            restart_ping_with_higher_interval
        fi
        sleep 1
    done
    echo "`timestamp` PingMonitor:Stopping ping monitor"
}

# Function to set ping cronjob on bootup, this will be invoked from the startup service
setcronjob () {

    pingCheck=`sh /lib/rdk/cronjobs_update.sh "check-entry" "ping-telemetry.sh"`

    if [ "$pingCheck" == "0" ]; then
        sh /lib/rdk/cronjobs_update.sh "add" "ping-telemetry.sh" "0 0 * * * /bin/sh /lib/rdk/ping-telemetry.sh >> /opt/logs/ping_telemetry.log"
    fi

}

# Decides the functionality based on the argument
if [ "$1" == "start" ]; then
    touch $ping_monitor_file
    monitor_cpu
elif [ "$1" == "stop" ]; then
    rm $ping_monitor_file
elif [ "$1" == "setcron" ]; then
    setcronjob
fi


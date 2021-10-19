#! /bin/sh
##########################################################################
# If not stated otherwise in this file or this component's LICENSE
# file the following copyright and licenses apply:
#
# Copyright 2016 RDK Management
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
##########################################################################

trap 'rm -f /tmp/.syslog_ng_update.lock' EXIT

tmp_log_path=/tmp/logs
log_path=/opt/logs
syslog_ng_config_file_path=/tmp/syslog-ng.conf

while true; do
    if [ -f /tmp/.syslog_ng_update.lock ];then
        echo "[syslog-ng]:Waiting to launch another instance..."
        sleep 10
        continue    
    fi
    break;
done

touch /tmp/.syslog_ng_update.lock

current_power_state=1

# Check current power state of the box
/QueryPowerState | grep "STANDBY\|LIGHTSLEEP"
if [ $? -eq 0 ]; then
   echo "[syslog-ng]:Current Power State : STANDBY OR LIGHTSLEEP"
   current_power_state=0
else
   echo "[syslog-ng]:Current Power State : ACTIVE"
   current_power_state=1
fi


flush_logs()
{

    # Move log files from /tmp/logs to /opt/logs, It is assumed that there won't be much logs during standby state
     cwd=`pwd`
     cd $tmp_log_path
     for file in `find -maxdepth 1 -size +0  -type f`;do
         cat $file >> $log_path/$file
         cat /dev/null > $file
     done 
     cd $cwd
}

# lightsleep check
if [ -f /tmp/.intermediate_sync ];then
   echo "[syslog-ng]:lightsleep intermediate sync"
   if [ $current_power_state  -eq 0 ];then
       flush_logs
   fi        
   rm -f /tmp/.intermediate_sync
   rm -f /tmp/.syslog_ng_update.lock
   exit 0
fi

if [ $current_power_state  -eq 0 ]; then  #Standby State
    #Redirect syslog configuration to /tmp/logs
    rm -rf $tmp_log_path/*
    mkdir -p $tmp_log_path

    sed -ie 's/opt\/logs/tmp\/logs/' $syslog_ng_config_file_path
    #Reload syslog stanby config file
    #/usr/local/sbin/syslog-ng-ctl reload   -c /tmp/syslog-ng/syslog-ng.ctl
    killall -HUP syslog-ng

else # Active State
    flush_logs
    sed -ie 's/tmp\/logs/opt\/logs/' $syslog_ng_config_file_path
    #Reload syslog active config file
    #/usr/local/sbin/syslog-ng-ctl reload   -c /tmp/syslog-ng/syslog-ng.ctl
    killall -HUP syslog-ng

fi
rm -f /tmp/.syslog_ng_update.lock
echo "[syslog-ng]:Script Completed"


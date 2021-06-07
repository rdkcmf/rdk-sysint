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


. /etc/device.properties

# initial check for power state to activate lightsleep
if [ -f /tmp/.standby ];then
     if [ ! -f /tmp/.intermediate_sync ];then
          exit 0
     else
          rm -rf /tmp/.intermediate_sync
     fi
fi

log_prefix="/opt/logs"

if [ -f /tmp/.xre-dumpinprogress ];then
    adate="`date +"%Y-%m-%d %T.%6N"`"
    echo "$adate: Log Dumping is in progress" >> $log_prefix/xre-dumpLog.txt
    exit 0
fi

touch /tmp/.xre-dumpinprogress

daemonarr=(xre-receiver wpeframework)
daemonlogarr=(${log_prefix}/receiver.log ${log_prefix}/wpeframework.log)

if [ ! -f /tmp/.xre-dump_application_log ]; then
	nice -n 19 dmesg -c >> ${log_prefix}/xre.log
	nice -n 19 journalctl -al > ${log_prefix}/xre-applications.log
	touch /tmp/.xre-dump_application_log
fi

appendLog()
{
  pid=$1
  unitname=$2
  logfile=$3

  journalctl_args="-u ${unitname}"

  # _PID param has higher prio => overrides unitname
  if [ -n "$pid" ]; then
      journalctl_args="${pid}"
  fi

  offset_file=/tmp/journalctl_${unitname}_offset
  offset_arg=""

  if [ -s "$offset_file" ]; then
      offset=`cat $offset_file`
      offset_arg="--after-cursor=$offset"
  fi

  skip_lines="^-- "
  offset_line="^-- cursor: s="

  journalctl_cmd="nice -n 19 journalctl ${journalctl_args} --show-cursor $offset_arg"

  $journalctl_cmd | grep -v "$skip_lines" | grep -v "Timer Service (R)" >> $logfile
  $journalctl_cmd | grep    "$offset_line" | grep -oE 's=.*$' > ${offset_file}
}

logunit()
{
   unitstring=$1
   logname=$2
   timestampname=`echo $logname | awk -F "/" '{print $NF}'`
   if [ ! -f $logname ]; then
       nice -n 19 journalctl -o short-precise --show-cursor ${unitstring} | grep -v '^-- Logs begin' \
         | awk "{ if (/-- cursor/) { print > \"/tmp/.${timestampname}_log_timestamp\" } else { print >> \"${logname}\" } }"
   else
       cursorValue=`/bin/cat /tmp/.${timestampname}_log_timestamp`
       if [ "$cursorValue" ]; then
           nice -n 19 journalctl -o short-precise --show-cursor $unitstring \
             --after-cursor="$cursorValue" \
             | grep -v '^-- Logs begin' \
             | awk "{ if (/-- cursor/) { print > \"/tmp/.${timestampname}_log_timestamp\" } else { print >> \"${logname}\" } }"
       else
           nice -n 19 journalctl -o short-precise --show-cursor $unitstring \
           | grep -v '^-- Logs begin' \
           | awk "{ if (/-- cursor/) { print > \"/tmp/.${timestampname}_log_timestamp\" } else { print >> \"${logname}\" } }"

       fi
   fi
   sed -i -e "s/-- cursor: //g" "/tmp/.${timestampname}_log_timestamp"

}

for ((i=${#daemonarr[@]}; i >= 0; i--)); do
        if [ "x${daemonarr[$i]}" == "x" ];then
           continue
        fi
        logunit "-xu ${daemonarr[$i]}" ${daemonlogarr[$i]}
done

rm -f  /tmp/.xre-dumpinprogress
exit 0

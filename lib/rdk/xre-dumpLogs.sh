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

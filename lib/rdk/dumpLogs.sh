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
if [ -f /tmp/.standby ] && [ "$LIGHTSLEEP_ENABLE" = "true" ];then
     if [ ! -f /tmp/.intermediate_sync ];then
         # Allow script to run till 20 Minutes of uptime to store all bootup logs on STANDBY mode
         if [ $(cat /proc/uptime | cut -d ' ' -f1 | cut -d '.' -f1) -gt 1200 ];then
             exit 0
         fi
     else
          rm -rf /tmp/.intermediate_sync
     fi
fi

log_prefix="/opt/logs"

if [ -f /tmp/.dumpinprogress ];then
    adate="`date +"%Y-%m-%d %T.%6N"`"
    /bin/echo "$adate: Log Dumping is in progress" >> $log_prefix/dumpLog.txt
    exit 0
fi

touch /tmp/.dumpinprogress

if [ "$DOBBY_ENABLED" == "true" ]; then
genericdaemonlist="gstreamer-cleanup mfrlibapp vodclientapp authservice socprovisioning socprovisioning-crypto xre-receiver xupnp xcal-device card-provision-check btmgr dibbler storagemgrmain fog audiocapturemgr parodus tr69hostif stunnel rfc-config dnsmasq update-device-details btrLeAppMgr ping-telemetry nlmon zram cgrpmemory cgrpmemorytest wpeframework apps-rdm dropbear vitalprocess-info appmanager iptables log-rdk-start xdial moca-status moca-driver moca cpuprocanalyzer rbus logrotatei systimemgr dobby telemetry2_0 bluetooth residentapp ermgr"
genericdaemonloglist="${log_prefix}/gst-cleanup.log ${log_prefix}/mfrlib_log.txt  ${log_prefix}/vodclient_log.txt ${log_prefix}/authservice.log ${log_prefix}/socprov.log ${log_prefix}/socprov-crypto.log ${log_prefix}/receiver.log ${log_prefix}/xdiscovery.log  ${log_prefix}/xdevice.log ${log_prefix}/card-provision-check.log ${log_prefix}/btmgrlog.txt ${log_prefix}/dibbler.log ${log_prefix}/storagemgr.log ${log_prefix}/fog.log ${log_prefix}/audiocapturemgr.log ${log_prefix}/parodus.log ${log_prefix}/tr69hostif.log ${log_prefix}/stunnel.log ${log_prefix}/rfcscript.log ${log_prefix}/dnsmasq.log ${log_prefix}/device_details.log ${log_prefix}/btrLeAppMgr.log ${log_prefix}/ping_telemetry.log ${log_prefix}/nlmon.log ${log_prefix}/applications.log ${log_prefix}/cgrpmemory.log ${log_prefix}/cgrmemorytest.log ${log_prefix}/wpeframework.log ${log_prefix}/rdm_status.log ${log_prefix}/dropbear.log ${log_prefix}/top_log.txt ${log_prefix}/appmanager.log ${log_prefix}/iptables.log ${log_prefix}/rdk_milestones.log ${log_prefix}/xdial.log ${log_prefix}/mocaStatus.log ${log_prefix}/moca-driver.log ${log_prefix}/mocaService.log ${log_prefix}/cpuprocanalyzer.log ${log_prefix}/rtrouted.log ${log_prefix}/logrotate.log ${log_prefix}/systimemgr.log ${log_prefix}/dobby.log ${log_prefix}/telemetry2_0.txt.0 ${log_prefix}/bluez.log ${log_prefix}/residentapp.log ${log_prefix}/wpeframework.log"
else
genericdaemonlist="gstreamer-cleanup mfrlibapp vodclientapp authservice socprovisioning socprovisioning-crypto xre-receiver xupnp xcal-device card-provision-check btmgr dibbler storagemgrmain fog audiocapturemgr parodus tr69hostif stunnel rfc-config dnsmasq update-device-details btrLeAppMgr ping-telemetry nlmon zram cgrpmemory cgrpmemorytest wpeframework apps-rdm dropbear vitalprocess-info appmanager iptables log-rdk-start xdial moca-status moca-driver moca cpuprocanalyzer rbus logrotatei systimemgr telemetry2_0 bluetooth residentapp ermgr"
genericdaemonloglist="${log_prefix}/gst-cleanup.log ${log_prefix}/mfrlib_log.txt  ${log_prefix}/vodclient_log.txt ${log_prefix}/authservice.log ${log_prefix}/socprov.log ${log_prefix}/socprov-crypto.log ${log_prefix}/receiver.log ${log_prefix}/xdiscovery.log  ${log_prefix}/xdevice.log ${log_prefix}/card-provision-check.log ${log_prefix}/btmgrlog.txt ${log_prefix}/dibbler.log ${log_prefix}/storagemgr.log ${log_prefix}/fog.log ${log_prefix}/audiocapturemgr.log ${log_prefix}/parodus.log ${log_prefix}/tr69hostif.log ${log_prefix}/stunnel.log ${log_prefix}/rfcscript.log ${log_prefix}/dnsmasq.log ${log_prefix}/device_details.log ${log_prefix}/btrLeAppMgr.log ${log_prefix}/ping_telemetry.log ${log_prefix}/nlmon.log ${log_prefix}/applications.log ${log_prefix}/cgrpmemory.log ${log_prefix}/cgrmemorytest.log ${log_prefix}/wpeframework.log ${log_prefix}/rdm_status.log ${log_prefix}/dropbear.log ${log_prefix}/top_log.txt ${log_prefix}/appmanager.log ${log_prefix}/iptables.log ${log_prefix}/rdk_milestones.log ${log_prefix}/xdial.log ${log_prefix}/mocaStatus.log ${log_prefix}/moca-driver.log ${log_prefix}/mocaService.log ${log_prefix}/cpuprocanalyzer.log ${log_prefix}/rtrouted.log ${log_prefix}/logrotate.log ${log_prefix}/systimemgr.log ${log_prefix}/telemetry2_0.txt.0 ${log_prefix}/bluez.log ${log_prefix}/residentapp.log ${log_prefix}/wpeframework.log"
fi

if [ "${DEVICE_TYPE}" = "mediaclient" ]; then
ocapdaemonlist=(rmfstreamer)
ocaplogname="${log_prefix}/rmfstr_log.txt"
daemonarr=(${genericdaemonlist} tr69agent netsrvmgr systemd-timesyncd xi-connection-stats wifi-telemetry virtual-wifi-iface)
daemonlogarr=(${genericdaemonloglist} ${log_prefix}/tr69agent.log ${log_prefix}/netsrvmgr.log ${log_prefix}/ntp.log ${log_prefix}/xiConnectionStats.txt ${log_prefix}/wifi_telemetry.log ${log_prefix}/dhcp-wifi.log)
uimgrdaemonlist=(iarmbusd irmgr dsmgr sysmgr diskmgr pwrmgr mfrmgr tr69bus deepsleepmgr)
uimgrlogname="${log_prefix}/uimgr_log.txt"
else
ocapdaemonlist=(rmfstreamer runpod runsnmp sdvagent)
ocaplogname="${log_prefix}/ocapri_log.txt"
daemonarr=(trm-srv wsproxy ${genericdaemonlist} snmpd ecmlogger network-statistics udhcp discover-xi-client syssnmpagent)
daemonlogarr=(${log_prefix}/trm.log ${log_prefix}/trm.log ${genericdaemonloglist}  ${log_prefix}/snmpd.log ${log_prefix}/messages-ecm.txt ${log_prefix}/upstream_stats.log ${log_prefix}/applications.log ${log_prefix}/discoverV4Client.log ${log_prefix}/mocalog.txt)
uimgrdaemonlist=(iarmbusd irmgr dsmgr sysmgr diskmgr pwrmgr mfrmgr)
uimgrlogname="${log_prefix}/uimgr_log.txt"
trmdaemonlist=(trm-srv wsproxy)
trmlogname="${log_prefix}/trm.log"
fi

hwselflogname="${log_prefix}/hwselftest.log"
systemdaemonlist=(busybox-klogd busybox-syslog usb-input@*.service usbmodule-whitelist.service logrotate ocsp-support.service)
systemlogname="${log_prefix}/messages.txt"
rf4cedaemonlist=(greenpeak rfmgr rf4ce deviceupdatemgr vrexmgr)
rf4celogname="${log_prefix}/rf4ce_log.txt"
ctrlmdaemonlist=(ctrlm-main ctrlm-hal-rf4ce)
ctrlmlogname="${log_prefix}/ctrlm_log.txt"
cecdaemonlist=(cecdaemon cecdevmgr)
ceclogname="${log_prefix}/cec_log.txt"
mountdaemonlist=(nvram prepare-nvram common-attach opt-attach disk-check)
mountlogname="${log_prefix}/mount_log.txt"
if [ "$SKY_EPG_SUPPORT" == "true" ] || [ "$SKY_SERVICE_LOGGING" == "true" ]; then
  skycomponentslist=(sky*)
  skycomponentslogname="${log_prefix}/sky-messages.log"
fi
subttxrendapplist=(subttxrend-app)
subttxrendappname="${log_prefix}/subttxrend-app.log"

if [ ! -f /tmp/.dump_application_log ]; then
	/bin/nice -n 19 /bin/dmesg -c > ${log_prefix}/startup_stdout_log.txt
	/bin/nice -n 19 /bin/journalctl -al > ${log_prefix}/applications.log
	touch /tmp/.dump_application_log
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

  journalctl_cmd="/bin/nice -n 19 /bin/journalctl ${journalctl_args} -q --show-cursor $offset_arg"

  $journalctl_cmd | grep -v "$skip_lines" | grep -v "Timer Service (R)" >> $logfile

  $journalctl_cmd | grep    "$offset_line" | grep -oE 's=.*$' > ${offset_file}
}

logunit()
{
   unitstring=$1
   logname=$2

   # transparent filtering arguments
   # | grep $matching_string | cut -d "$field_separator" -f $field_number
   matching_string=$3
   field_separator=$4
   field_number=$5

   if [ -z "${unitstring}" -o -z "${logname}" ]; then
       return
   fi

   timestampname=`echo $logname | awk -F "/" '{print $NF}'`

   cmd="nice -n 19 /bin/journalctl"

   # filter log by 'matching_string' if passed
   more_opts=""
   if [ "x$matching_string" != "x" ]; then
       more_opts="|grep -i -e $matching_string -e cursor"
   fi

   # filter by 'field_separator' and 'field_number' if passed
   awk_field_separator=""
   awk_field_number=""
   if [ "x$field_separator" != "x" -o "x$field_number" != "x" ]; then
       awk_field_separator="-F \"$field_separator\""
       awk_field_number="\\\$$field_number"
   fi

   if [ ! -f $logname ]; then
       opts="--no-hostname -o short-precise -q --show-cursor ${unitstring}"
       whole_cmd="$cmd $opts $more_opts | awk $awk_field_separator \"{ if (/-- cursor/) { print > \\\"/tmp/.${timestampname}_log_timestamp\\\" } \
                  else { print $awk_field_number >> \\\"${logname}\\\" } }\""
   else
       cursorValue=`/bin/cat /tmp/.${timestampname}_log_timestamp`
       if [ "$cursorValue" ]; then
           opts="--no-hostname -o short-precise -q --show-cursor $unitstring --after-cursor=\"$cursorValue\""
           whole_cmd="$cmd $opts $more_opts | awk $awk_field_separator \"{ if (/-- cursor/) { print > \\\"/tmp/.${timestampname}_log_timestamp\\\" } \
                      else { print $awk_field_number >> \\\"${logname}\\\" } }\""
       else
           opts="--no-hostname -o short-precise -q --show-cursor $unitstring"
           whole_cmd="$cmd $opts $more_opts | awk $awk_field_separator \"{ if (/-- cursor/) { print > \\\"/tmp/.${timestampname}_log_timestamp\\\" } \
                      else { print $awk_field_number >> \\\"${logname}\\\" } }\""
       fi
   fi

   eval "$whole_cmd"
   sed -i -e "s/-- cursor: //g" "/tmp/.${timestampname}_log_timestamp"

}


###### system logging
systemunits=""
for ((systemunit=${#systemdaemonlist[@]}; systemunit >= 0; systemunit--)); do
        if [ "x${systemdaemonlist[$systemunit]}" == "x" ];then
           continue
        fi
        preunit=$systemunits
        systemunits="$preunit -u ${systemdaemonlist[$systemunit]} "
done
logunit "$systemunits" $systemlogname


if [ ! -f /tmp/.dump_messages_log ]; then
	touch /tmp/.dump_messages_log
fi

###### ecfs logging
ecfsdaemonlist=(ecryptfs securemount ecfs-init)
ecfslogname="${log_prefix}/ecfs.txt"

ecfsunits=""
for ((ecfsunit=${#ecfsdaemonlist[@]}; ecfsunit >= 0; ecfsunit--)); do
        if [ "x${ecfsdaemonlist[$ecfsunit]}" == "x" ];then
           continue
        fi
        preunit=$ecfsunits
        ecfsunits="$preunit -u ${ecfsdaemonlist[$ecfsunit]} "
done
logunit "$ecfsunits" $ecfslogname


###### hwselftest logging

# log filter by SyslogIdentifier instead of unit name
hwselfunits="SYSLOG_IDENTIFIER=\\\"tr69hostif\\\""

# log hwselftest output
#  - include only lines containing string "HWST_LOG"
#    - out of them take second field using pipe char "|" as field separator
logunit "$hwselfunits" $hwselflogname "HWST_LOG" "|" 2

# push latest results to persistant storage
if [ -f /tmp/hwselftest.results ]; then
    cp /tmp/hwselftest.results ${log_prefix}/
fi

######ocap logging
ocapunits=""
for ((ocapunit=${#ocapdaemonlist[@]}; ocapunit >= 0; ocapunit--)); do
        if [ "x${ocapdaemonlist[$ocapunit]}" == "x" ];then
           continue
        fi
        preunit=$ocapunits
        ocapunits="${preunit} -u ${ocapdaemonlist[${ocapunit}]} "
done
logunit "$ocapunits" $ocaplogname

###### uimgr logging
uimgrunits=""
for ((uimgrunit=${#uimgrdaemonlist[@]}; uimgrunit >= 0; uimgrunit--)); do
        if [ "x${uimgrdaemonlist[$uimgrunit]}" == "x" ];then
           continue
        fi
        preunit=$uimgrunits
        uimgrunits="$preunit -u ${uimgrdaemonlist[$uimgrunit]} "
done
logunit "$uimgrunits" $uimgrlogname

###### trm logging
trmunits=""
for ((trmunit=${#trmdaemonlist[@]}; trmunit >= 0; trmunit--)); do
        if [ "x${trmdaemonlist[$trmunit]}" == "x" ];then
           continue
        fi
        preunit=$trmunits
        trmunits="$preunit -u ${trmdaemonlist[$trmunit]} "
done
logunit "$trmunits" $trmlogname

###### cec logging
cecunits=""
for ((cecunit=${#cecdaemonlist[@]}; cecunit >= 0; cecunit--)); do
        if [ "x${cecdaemonlist[$cecunit]}" == "x" ];then
           continue
        fi
        preunit=$cecunits
        cecunits="$preunit -u ${cecdaemonlist[$cecunit]} "
done
logunit "$cecunits" $ceclogname
###### rf4cemgr logging
rf4ceunits=""
for ((rf4ceunit=${#rf4cedaemonlist[@]}; rf4ceunit >= 0; rf4ceunit--)); do
        if [ "x${rf4cedaemonlist[$rf4ceunit]}" == "x" ];then
           continue
        fi
        preunit=$rf4ceunits
        rf4ceunits="$preunit -u ${rf4cedaemonlist[$rf4ceunit]} "
done
logunit "$rf4ceunits" $rf4celogname
###### ctrlm logging
ctrlmunits=""
for ((ctrlmunit=${#ctrlmdaemonlist[@]}; ctrlmunit >= 0; ctrlmunit--)); do
        if [ "x${ctrlmdaemonlist[$ctrlmunit]}" == "x" ];then
           continue
        fi
        preunit=$ctrlmunits
        ctrlmunits="$preunit -u ${ctrlmdaemonlist[$ctrlmunit]} "
done
logunit "$ctrlmunits" $ctrlmlogname
###### mount logging
mountunits=""
for ((mountunit=${#mountdaemonlist[@]}; mountunit >= 0; mountunit--)); do
        if [ "x${mountdaemonlist[$mountunit]}" == "x" ];then
           continue
        fi
        preunit=$mountunits
        mountunits="$preunit -u ${mountdaemonlist[$mountunit]} "
done
logunit "$mountunits" $mountlogname
###### subttxrend-app logging
subttxrendapplist=(subttxrend-app)
subttxrendappname="${log_prefix}/subttxrend-app.log"

subttxrendunits=""
for ((subttxrendunit=${#subttxrendapplist[@]}; subttxrendunit >= 0; subttxrendunit--)); do
        if [ "x${subttxrendapplist[$subttxrendunit]}" == "x" ];then
           continue
        fi
        preunit=$subttxrendunits
        subttxrendunits="$preunit -u ${subttxrendapplist[$subttxrendunit]} "
done
logunit "$subttxrendunits" $subttxrendappname

for ((i=${#daemonarr[@]}; i >= 0; i--)); do
        if [ "x${daemonarr[$i]}" == "x" ];then
           continue
        fi

        if [ "x${daemonarr[$i]}" == "xdropbear" ];then
            logunit "_COMM=dropbear" ${daemonlogarr[$i]}
        else                                                                                                                                                                             
            logunit "-xu ${daemonarr[$i]}" ${daemonlogarr[$i]}
        fi   
done

if [ "$SKY_EPG_SUPPORT" == "true" ] || [ "$SKY_SERVICE_LOGGING" == "true" ]; then
  for ((skyunit=${#skycomponentslist[@]}; skyunit >= 0; skyunit--)); do
        if [ "x${skycomponentslist[$skyunit]}" == "x" ];then
           continue
        fi
        preunit=$skyunits
        skyunits="$preunit -u ${skycomponentslist[$skyunit]} "
  done
  logunit "$skyunits" $skycomponentslogname
fi

#/bin/nice /bin/dmesg  >> ${log_prefix}/messages.txt
#/bin/nice /bin/journalctl -xu xre-receiver > ${log_prefix}/runXRE_log.txt
#/bin/nice journalctl _PID=1 > ${log_prefix}/system.log
appendLog _PID=1 systemd ${log_prefix}/system.log

if [ "$LIGHTSLEEP_ENABLE" = "true" ];then
      logunit "-u power-state-monitor" ${log_prefix}/lightsleep.log
fi

if [ "$SOC" = "BRCM" ];then
      logunit "-u nxserver" ${log_prefix}/nxserver.log
      if [ "$PROC_STATUS_LOG_SUPPORT" = "true" ];then
          logunit "-u proc-status-logger" ${log_prefix}/proc-status-logger.log
      fi
fi

if [ "$SOC" = "AMLOGIC" ];then
      logunit "-u audioserver" ${log_prefix}/audioserver.log
      logunit "-u tvserver" ${log_prefix}/tvservice.log
      logunit "-u pqserver" ${log_prefix}/pqserver.log
      logcat -v time -d -f ${log_prefix}/dolby_ms12.log
      logcat -c
fi

if [ "$DEVICE_NAME" = "PLATCO" ]; then
      logunit "-u factorycomms" ${log_prefix}/factoryComms.log
fi

if [ "$MEDIARITE" = "true" ];then
      logunit "-u mediarite" ${log_prefix}/mediarite.log
fi

if [ "${DEVICE_TYPE}" = "hybrid" ]; then
      logunit "-u trmmgr" ${log_prefix}/trmmgr.log
fi

if [ ! -f /etc/os-release ]; then
	sh /lib/rdk/vitalProcessInfo.sh >> ${log_prefix}/top_log.txt
fi

### Required to add ecfs.txt log missing under /opt/logs due to journal limitation
if [ ! -f ${log_prefix}/ecfs.txt ]; then
    grep -rn 'ecfs\|ecryptfs' ${log_prefix}/applications.log >> ${log_prefix}/ecfs.txt
fi

### Adding support for named.log and dnsquery.log
if [ "x$BIND_ENABLED" = "xtrue" ];then
   sh /lib/rdk/add_bindlogs.sh
fi

#XRE-13845
#Backup cusor values for receiver.log for xre-receiver unit
#Pass container user id for container and store cursor value for redirecting container journal logs to reciver.log
if [ -f /opt/XRE_container_enable ]; then
      cp /tmp/.receiver.log_log_timestamp /tmp/.receiver.log_log_timestamp_backup
      rm -f /tmp/.receiver.log_log_timestamp
      if [ -f /tmp/.receiver.log_log_timestamp_container ]; then
          mv /tmp/.receiver.log_log_timestamp_container /tmp/.receiver.log_log_timestamp
      fi
      logunit "_UID=704" ${log_prefix}/receiver.log
      cp /tmp/.receiver.log_log_timestamp /tmp/.receiver.log_log_timestamp_container
      rm -f /tmp/.receiver.log_log_timestamp
      mv /tmp/.receiver.log_log_timestamp_backup /tmp/.receiver.log_log_timestamp
fi
rm -f  /tmp/.dumpinprogress
exit 0

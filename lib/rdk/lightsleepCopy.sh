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
#

. /etc/include.properties
. /etc/device.properties
. /etc/env_setup.sh

if [ -f /etc/os-release ]; then
    exit 0
fi

createPipeNode()
{
   pipeName=$1
   mknodBin=`which mknod`
   if [ "$mknodBin" ];then
         $mknodBin $pipeName p >/dev/null
   fi
   mkfifoBin=`which mkfifo`
   if [ "$mkfifoBin" ];then
         $mkfifoBin $pipeName >/dev/null
   fi
}

if [ "$LIGHTSLEEP_ENABLE" != "true" ] ; then exit; fi

. $RDK_PATH/stackUtils.sh

# pipe or not flag
flag=$1

HDD_PATH=$LOG_PATH
if [ $flag -eq 1 ]; then
    LOG_PATH=$LOG_PATH
else
    LOG_PATH=$TEMP_LOG_PATH
fi

LOG_FILE=$LOG_PATH/lightsleep.log

dbgenvPath=`setdbgenvPath`
if [ "$dbgenvPath" != "" ]; then
     isSeparateLog=`grep "SEPARATE.LOGFILE.SUPPORT" "$dbgenvPath" | cut -d '=' -f2`
fi

syncLog()
{
    cWD=`pwd`
    syncPath=`find $TEMP_LOG_PATH -type l -exec ls -l {} \; | cut -d ">" -f2 | tr -d ' '`
    if [ "$syncPath" != "$HDD_PATH" ] && [ -d "$TEMP_LOG_PATH" ]; then
         cd "$TEMP_LOG_PATH"
         for file in `ls *.txt *.log 2>/dev/null`
         do
            cat $file >> $HDD_PATH/$file
            cat /dev/null > $file
         done
         cd $cWD
    else
         echo "Sync Not needed, Same log folder"
    fi
}

if [ ! -f "/tmp/.lightsleep" ]; then
  if [ -f "/tmp/processIDs" ]; then
     while read line
     do              
          kill -9 $line                 
     done < /tmp/processIDs
     rm -rf /tmp/processIDs
     syncLog
  fi
else
  rm -rf /tmp/.lightsleep
fi

fileTypeCheck()
{
   file=$1
   output=$2
   count=`find $TEMP_LOG_PATH/ -name $file -type p | grep -v grep | wc -l`
   if [ $count -eq 0 ]; then
        echo "From lightsleep_copy -  PIPE /var/logs/$file" >> $LOG_FILE
        count1=`find $TEMP_LOG_PATH -name $file -type f`
        if [ "$count1" != "" ]; then
             cat $TEMP_LOG_PATH/$file >> $LOG_PATH/$output
             echo "$TEMP_LOG_PATH/$file is not a pipe" >> $LOG_FILE
             rm -rf $TEMP_LOG_PATH/$file
        fi
        createPipeNode $TEMP_LOG_PATH/$file
   fi
}

processCheck()
{
   pipeName=$1
   fileName=$2
   
   num=`ps | grep cat | grep -v grep | grep $pipeName | wc -l`
   if [ $num -eq 0 ]; then
        fileTypeCheck $pipeName $fileName
        echo "Calling $1 pipe" >> $LOG_FILE
        cat $TEMP_LOG_PATH/$pipeName >> $LOG_PATH/$fileName &
   fi
}

processCheck "pipe_messages" messages.txt

if [ "$isSeparateLog" = "TRUE" ] ; then
   echo "Separate Logs are enabled" >> $LOG_FILE
   processCheck "pipe_pod_log" pod_log.txt     
   processCheck "pipe_snmp_log" snmp_log.txt     
   processCheck "pipe_canh_log" canh_log.txt     
   processCheck "pipe_rmfstr_log" rmfstr_log.txt     
else
   processCheck "pipe_ocapri_log" ocapri_log.txt     
fi
processCheck "pipe_snmpd_log" snmpd.log
processCheck "pipe_upstream_stats_log" upstream_stats.log
processCheck "pipe_vodclient_log" vodclient_log.txt
processCheck "pipe_top_log" top_log.txt
processCheck "pipe_receiver" receiver.log
processCheck "pipe_uimgr_log" uimgr_log.txt
processCheck "pipe_rf4ce_log" rf4ce_log.txt
processCheck "pipe_trm_log" trm.log
processCheck "pipe_trmmgr_log" trmmgr.log
processCheck "pipe_xdiscovery_log" xdiscovery.log         
processCheck "pipe_fog_log" fog.log         

if [ "$SOC" != "BRCM" ];then
   processCheck "pipe_puma_messages" messages-puma.txt
else
   processCheck "pipe_dsmgr_log" uimgr_log.txt
   processCheck "pipe_mfrlib_log" mfr_log.txt
   processCheck "pipe_puma_messages" messages-ecm.txt
fi
#processCheck "pipe_xdiscoverylist_log" xdiscoverylist.log


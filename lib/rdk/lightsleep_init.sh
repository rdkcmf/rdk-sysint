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

if [ -f /etc/os-release ]; then
    exit 0
fi

if [ "$LIGHTSLEEP_ENABLE" != "true" ] ; then exit; fi

. $RDK_PATH/stackUtils.sh

dbgenvPath=`setdbgenvPath`
if [ "$dbgenvPath" != "" ]; then
     isSeparateLog=`grep "SEPARATE.LOGFILE.SUPPORT" "$dbgenvPath" | cut -d '=' -f2`
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

fileTypeCheck()
{
   file=$1
   output=$2
        count=`find $TEMP_LOG_PATH -name $file -type p | grep -v grep | wc -l`
        if [ $count -eq 0 ]; then
            echo "From lightsleep_init -  PIPE $TEMP_LOG_PATH/$file" >> $LOGFILE
            count1=`find $TEMP_LOG_PATH -name $file -type f`
            if [ "$count1" != "" ]; then
                cat $TEMP_LOG_PATH/$file >> $LOG_PATH/$output
                echo "$TEMP_LOG_PATH/$file is not a pipe" >> $LOGFILE
                rm -rf $TEMP_LOG_PATH/$file
            fi
            createPipeNode $TEMP_LOG_PATH/$file
        fi
}

removePipe()
{
   pipeName=$1
   if [ -p $TEMP_LOG_PATH/$pipeName ] ; then
        rm -rf $TEMP_LOG_PATH/$pipeName
   fi

}

removeSymLinks()
{
   cd $TEMP_LOG_PATH
   for file in `find . -type l | grep pipe`
   do
        rm -rf $file
   done 
   cd $dirName
}

dirName=`pwd`
removeSymLinks

LOGFILE=$LOG_PATH/lightsleep.log


echo "Lightsleep: Starting initialization." >> $LOGFILE
echo "Lightsleep: Ensuring valid pipes exist" >> $LOGFILE
if [ "$isSeparateLog" = "TRUE" ] ; then
   echo "Lightsleep:Separate Logs are enabled" >> $LOG_FILE
   fileTypeCheck pipe_pod_log pod_log.txt
   fileTypeCheck pipe_pod_log snmp_log.txt
   fileTypeCheck pipe_canh_log canh_log.txt
   fileTypeCheck pipe_rmfstr_log rmfstr_log.txt
else
   fileTypeCheck pipe_ocapri_log ocapri_log.txt
fi
fileTypeCheck pipe_snmpd_log snmpd.log
fileTypeCheck pipe_upstream_stats_log upstream_stats.log
fileTypeCheck pipe_vodclient_log vodclient_log.txt
fileTypeCheck pipe_receiver receiver.log
fileTypeCheck pipe_uimgr_log uimgr_log.txt
fileTypeCheck pipe_rf4ce_log rf4ce_log.txt
fileTypeCheck pipe_top_log top_log.txt
fileTypeCheck pipe_messages messages.txt
fileTypeCheck pipe_trm_log trm.log
fileTypeCheck pipe_trmmgr_log trmmgr.log
fileTypeCheck pipe_xdiscovery_log xdiscovery.log
fileTypeCheck pipe_fog_log fog.log
if [ "$SOC" != "BRCM" ];then      
   fileTypeCheck pipe_puma_messages messages-puma.txt
else
   fileTypeCheck pipe_dsmgr_log uimgr_log.txt
   fileTypeCheck pipe_mfrlib_log mfrlib_log.txt
   fileTypeCheck pipe_puma_messages messages-ecm.txt      
fi
#fileTypeCheck pipe_xdiscoverylist_log xdiscoverylist.log

# Invoke cats for named pipes
echo "Lightsleep: Invoking cats for named pipes" >> $LOGFILE
sleep 1
$RDK_PATH/lightsleepCopy.sh 1

# just make sure maf.txt get copied to /opt before it is used below
if [ -f /opt_back/maf.txt ]; then
     cp /opt_back/maf.txt /tmp/maf.txt
     cp /opt_back/maf.txt /opt/maf.txt
else
     if [ ! -f /tmp/maf.txt ]; then
         echo "list power" > /tmp/maf.txt
         echo "quit" >> /tmp/maf.txt
     fi
     cp /tmp/maf.txt /opt/maf.txt
fi	  

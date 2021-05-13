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
. /etc/config.properties
if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
     . /lib/rdk/getSecureDumpStatus.sh
fi

MEMORY_LOG="/opt/logs/core_log.txt"

if [ -f /etc/os-release ]; then
	CORE_PATH=$CORE_PATH
fi

if [ ! -d "$CORE_PATH" ]; then
     mkdir -p "$CORE_PATH"
fi

if [ "$DEVICE_TYPE" = "broadband" ];then
      MINDUMP_DIR=/minidumps/
else
      MINDUMP_DIR=$MINIDUMPS_PATH
fi

upload() {
    TS=`date +%Y-%m-%d-%H-%M-%S`
    # core+mini dumps to Crash Portal
    # Coredump Upload call
    if [ ! -f /etc/os-release ];then
         echo $(date -u +%Y/%m/%d-%H:%M:%S) "Starting upload processes from core_shell.sh" >> $LOG_PATH/core_log.txt
         if [ ! -z "$(ls -A $CORE_PATH 2> /dev/null)" ]; then
              sh $RDK_PATH/uploadDumps.sh ${TS} 1 &
         fi
         if [ ! -z "$(ls -A $MINDUMP_DIR 2> /dev/null)" ]; then
              sh $RDK_PATH/uploadDumps.sh ${TS} 0 &
         fi
    fi
    # Checking whether cores are leading to /opt size exceeding.
    count=`ls $CORE_PATH | grep $process | wc -l`
    while [ $count -gt 5 ]; do
        oldcore=`ls -t $CORE_PATH | grep $process | tail -1`
        echo "Deleting $oldcore as the same process has more than 5 cores in $CORE_PATH" >> $LOG_PATH/core_log.txt
        rm -rf $CORE_PATH/$oldcore
        count=`ls $CORE_PATH | grep $process | wc -l`
    done

    sh /lib/rdk/diskCleanup.sh
}

dumpMemoryStats()
{
    # dump needed statistics to $MEMORY_LOG, it will be archived to mini/coredump
    free >> $MEMORY_LOG 2>&1
    TERM=vt100 top -b -n1 >> $MEMORY_LOG 2>&1
    df >> $MEMORY_LOG 2>&1
}

dumpInfo()
{
   echo $(date -u +%Y/%m/%d-%H:%M:%S) "$1 crash and uploading the cores" >> $LOG_PATH/core_log.txt
   echo $(date -u +%Y/%m/%d-%H:%M:%S) "corename = $corename" >> $LOG_PATH/core_log.txt
   echo $(date -u +%Y/%m/%d-%H:%M:%S) "processing_corename = $processing_corename" >> $LOG_PATH/core_log.txt
   echo $(date -u +%Y/%m/%d-%H:%M:%S) "process crashed = $1" >> $LOG_PATH/core_log.txt
   echo $(date -u +%Y/%m/%d-%H:%M:%S) "signal causing dump = $2" >> $LOG_PATH/core_log.txt
   echo $(date -u +%Y/%m/%d-%H:%M:%S) "time of dump = $3" >> $LOG_PATH/core_log.txt
}

dumpFile()
{
    if [ -f /tmp/coredump_mutex_release ];then rm /tmp/coredump_mutex_release ; fi
    dumpInfo $process $signal $timestamp
    if [ "$HDD_ENABLED" = "false" ];then
        nice -n 19 gzip -f > $CORE_PATH/$processing_corename
        if [[ $? -ne 0 ]]; then
            rm $CORE_PATH/$processing_corename
            exit 1
        fi
        mv $CORE_PATH/$processing_corename $CORE_PATH/$corename
        # fix file permissions
        chmod a+r $CORE_PATH/$corename
        touch /tmp/.$corename.core_dump
    else
        ### Changing to use cat for efficiency
        ### reasons.
        cat > $CORE_PATH/$corename
    fi
    touch /tmp/coredump_mutex_release
}

dumpSystemdLogs()
{
    echo $(date -u +%Y/%m/%d-%H:%M:%S) "****************SYSTEMD CRASHED DUMPING LOGS START*****************" >> $LOG_PATH/core_log.txt
    journalctl -b  >> $LOG_PATH/core_log.txt
    echo $(date -u +%Y/%m/%d-%H:%M:%S) "****************SYSTEMD CRASHED DUMPING LOGS END*****************" >> $LOG_PATH/core_log.txt
    
    sh /lib/rdk/dumpLogs.sh
    sync
}

dumpMemoryStats

#fallthrough rule: saving last url as crashed url for crashportal processing
if [ "$1" = "WPEWebProcess" ]; then
    cp /opt/logs/last_url.txt /opt/logs/crashed_url.txt || true
fi

process=$1
signal=$2
timestamp=$3
if [ "$HDD_ENABLED" = "false" ];then
     corename="$3_core.prog_$1.signal_$2.gz"
     # we have to have processing_corename that is not touched by uploadDumps.sh
     processing_corename="$3_core_prog_$1.signal_$2.gz.tmp"
     # always try to upload core/minidumps at exit
     trap "{ upload ; }" EXIT;
else
     corename="$3_core.prog_$1.signal_$2"
     processing_corename="$3_core.prog_$1.signal_$2"
     # always try to upload core/minidumps at exit
     trap "{ upload ; }" EXIT;
     dumpFile
     # Call dumpLogs.sh script for systemd crash
     if [ "$1" = "systemd" ]; then
        echo $(date -u +%Y/%m/%d-%H:%M:%S) "$1 crashed with SIGNAL $2, Dumping Journal logs from boot"  >> $LOG_PATH/core_log.txt
        dumpSystemdLogs
     fi
     exit 0
fi

# uimanager support
if [ "$IARM_DEPENDENCY_ENABLE" = "false" ]; then
     if [ "$1" = "uimgr_main" ]; then
          dumpFile
          exit 0
     fi
fi
# Delia build specific
if [ "$DEVICE_TYPE" = "hybrid" ]; then
     if [ "$1" = "rmfStreamer" ]; then
          echo 0 > /tmp/.uploadRMFCores
          echo $corename >> /tmp/.rmf_crashed
          dumpFile
          exit 0
     fi
     if [ "$1" = "runPod" ]; then
          echo 0 > /tmp/.uploadPodCores
          echo $corename >> /tmp/.pod_crashed
          dumpFile
          exit 0
     fi
     if [ "$1" = "runSnmp" ]; then
          echo 0 > /tmp/.uploadSnmpCores
          echo $corename >> /tmp/.snmp_crashed
          dumpFile
          exit 0
     fi
     if [ "$1" = "dibbler-client" ]; then
          echo 0 > /tmp/.uploadDibblerCores
          echo $corename >> /tmp/.dibbler_crashed
          dumpFile
          exit 0
     fi
# Regular build specific
elif [ "$DEVICE_TYPE" != "mediaclient" ]; then
     if [ "$1" = "mpeos-main" ]; then
          echo 0 > /opt/.uploadMpeosCores
          echo $corename >> /opt/.mpeos_crashed
          dumpFile
          exit 0
     fi
# mediaclient specific
else
     if [ "$1" = "rmfStreamer" ]; then
          echo 0 > /tmp/.uploadRMFCores
          echo $corename >> /tmp/.rmf_crashed
          dumpFile
     elif [ "$1" = "tr69agent" ] || [ "$1" =  "tr69hostif" ] || [ "$1" = "runTR69HostIf" ] ||
                [ "$1" = "tr69BusMain" ] || [ "$1" = "dimclient" ]; then
          dumpFile
     elif [ "$1" = "netsrvmgr" ] || [ "$1" = "udhcpc" ]; then
         dumpFile
     elif [ "$1" = "nxserver" ] && [ "$SOC" = "BRCM" ]; then
         dumpFile
     else
           echo ""
     fi
fi

# enable CEF coredumps for non-PROD builds
if [ "$1" = "cef_subprocess" ]; then
    if [ "$BUILD_TYPE" == "prod" ]; then
        echo "Not writing CEF core-dump in PROD"
    else
        dumpFile
    fi
    exit 0
fi

if [ "$1" = "Receiver" ]; then
     if [ "$BUILD_TYPE" != "dev" ]; then
           echo "Not writing Receiver core-dump in VBN/PROD"
     else
           if [ "$DEVICE_TYPE" = "mediaclient" ]; then
		cp /tmp/typefind.ts $PERSISTENT_SEC_PATH/$3_$1_signal_$2_typefind.ts
           fi
           dumpFile
     fi
     exit 0
fi

if [ "$1" = "rdkbrowser2" ]; then
     if [ "$2" = "11" ]; then
           echo "Writing rdkbrowser2 core-dump when signal is SIGSEGV"
           dumpFile
     fi
     exit 0
fi

if [ "$DEVICE_TYPE" != "mediaclient" ]; then
     if [ "$1" = "WPEWebProcess" ] || [ "$1" = "WPEIPVideo" ]; then
          dumpFile
          exit 0
     fi
fi

if [ "$HDD_ENABLED" = "false" ] && [ "$1" = "rf4ceMgr" ];then
      echo "No space to hold rf4ceMgr coredump and no support for minidump..!"
      exit 0
fi

if  [ "$1" = "xcal-discovery-" ] || [ "$1" = "xdiscovery" ] || [ "$1" = "IARMDaemonMain" ] ||
    [ "$1" = "AppMSOTarget" ] || [ "$1" = "dsMgrMain" ] || [ "$1" = "irMgrMain" ] ||
    [ "$1" = "pwrMgrMain" ] || [ "$1" = "mfrMgrMain" ] || [ "$1" = "sysMgrMain" ] ||
    [ "$1" = "vrexMgrMain" ] || [ "$1" = "deviceUpdateMgrMain" ] || [ "$1" = "CecDaemonMain" ] ||
    [ "$1" = "socprovisioning" ] || [ "$1" = "xcal-device" ] || [ "$1" = "vodClientApp" ] ||
    [ "$1" = "dvrsrc:src" ] || [ "$1" = "qsrc:src" ] ||
    [ "$1" = "qamsrc_bin-queu" ] || [ "$1" = "authservice" ] || [ "$1" = "named" ] ||
    [ "$1" = "slave_callback" ] ; then
        dumpFile
        exit 0
fi


if [ "$SKY_EPG_SUPPORT" = "true" ] || [ "$SKY_SERVICE_LOGGING" == "true" ]; then
    APP_NAMES=( "appsserviced" "dropbear"
        "asrdkplayer" "asproxy" "DobbyDaemon"
        "DobbyInit" "epg_ui" "asmockservice"
        "ASSystemService" "BleRcuDaemon"
        "VoiceSearchDaemon" "VoiceSearchDaem"
        "ASNetworkService" "ASNetworkServic" )

    for anAppName in "${APP_NAMES[@]}"; do
        if [ "$1" = "${anAppName}" ]; then
            dumpFile
            exit 0
        fi
    done
fi

exit 0


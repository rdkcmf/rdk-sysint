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



# set -x
# Shell script to monitor or watch the disk space
# -------------------------------------------------------------------------
# set alert level 90% is default

. /etc/device.properties
. /etc/include.properties
. $RDK_PATH/commonUtils.sh
if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
     . /lib/rdk/getSecureDumpStatus.sh
fi

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

# flag to indicate the call time (bootup call /runtime call by disk check script)
FLAG=$1
# default cleanup path and size for bootup cleanup

if [ "$HDD_ENABLED" = "false" ];then
     DEFAULT_THRESHOLD_SIZE=80
else
     DEFAULT_THRESHOLD_SIZE=90
fi
WORK_PATH=$PERSISTENT_PATH
LOG_FILE=/tmp/disk_cleanup.log
usep=0
count=1

echo "`Timestamp` ---Received call to disk_threshold_check.sh ----" >> /tmp/disk_cleanup.log

if [ -e /tmp/mnt/diska3/persistent ] && [ -f /usr/bin/file ] ; then
    echo "Persistent location type - `file /tmp/mnt/diska3/persistent`" >> /tmp/disk_cleanup.log
fi

if [ -f /tmp/DiskCheck.pid ]
then
   pid=`cat /tmp/DiskCheck.pid`
   if [ -d /proc/$pid ]
   then
      echo "`Timestamp` An instance of disk_threshold_check.sh with pid $pid is already running.." >> /tmp/disk_cleanup.log
      echo "`Timestamp` Exiting script" >> /tmp/disk_cleanup.log
      exit 0
   fi
fi

echo $$ > /tmp/DiskCheck.pid

counter()
{
  val=$1
  num=`expr $val + 1`
  echo $num
}

deleteMaxFile()                                                   
{
    #Don't delete the log file. Instead empty it.
    find $LOG_PATH -type f | xargs ls -S > /tmp/deletionList.txt
    maxFile=`head -n 1 /tmp/deletionList.txt`
    echo "Max File: $maxFile" >> /tmp/disk_cleanup.log
    if [ -f $maxFile ]; then
         echo "Emptying the file due to size issue `ls -l $maxFile`" >> /tmp/disk_cleanup.log
         cat /dev/null > $maxFile
    fi
}

check_jffs_garbage_collection_status()
{
    echo "In check_jffs_garbage_collection_status" >> /tmp/disk_cleanup.log

    #Identify the complete JFFS partition of /opt for monitoring JFFS Garbage collection CPU cycles
    jffs_block_num=`df -kh /opt | grep -v 'Filesystem' | awk '{print $1}'|sed 's/\/dev\/mtdblock//g'`
    jffs_partition_name="jffs2_gcd_mtd""$jffs_block_num"
    echo "jffs_partition_name=$jffs_partition_name" >> /tmp/disk_cleanup.log

    #Get First CPU cycle of JFFS Garabage collection in seconds
    old_jffs_sec=`top -b -n 1 | grep $jffs_partition_name | awk '{print $11}' | awk -F ':' '{print ($1 * 60) + $2 }'`

    sleep 2

    #Get Second CPU cycle of JFFS Garabage collection in seconds after sleep operation
    new_jffs_sec=`top -b -n 1 | grep $jffs_partition_name | awk '{print $11}' | awk -F ':' '{print ($1 * 60) + $2 }'`

    echo "before while: old_jffs_sec=$old_jffs_sec, new_jffs_sec=$new_jffs_sec" >> /tmp/disk_cleanup.log

    #Check whether the JFFS2 Garbage collection is active on /opt between the 2 iterations of Total time CPU cycles
    loop=`echo $old_jffs_sec $new_jffs_sec  | awk '{if ($1 == $2) print 0; else print 1}'`

    #Loop only when the 2nd Iteration of Total time CPU usage is higher than 1st Iteration for JFFS2 Garbage collection
    while [ $loop -eq 1 ]
    do
       #Store the Last Iteration of CPU cycle of JFFS Garabage for comparison with New iterative value
       old_jffs_sec=`expr $new_jffs_sec`

       sleep 2

       #Get New CPU cycle of JFFS Garabage collection in seconds after sleep operation
       new_jffs_sec=`top -b -n 1 | grep "jffs2_gcd_mtd4" | awk '{print $11}' | awk -F ':' '{print ($1 * 60) + $2 }'`

       echo "in while: old_jffs_sec=$old_jffs_sec, new_jffs_sec=$new_jffs_sec" >> /tmp/disk_cleanup.log

       # Check whether the JFFS2 Garbage collection is active on /opt between the 2 iterations of Total time CPU cycles
       loop=`echo $old_jffs_sec $new_jffs_sec  | awk '{if ($1 == $2) print 0; else print 1}'`
    done

    echo "exiting check_jffs_garbage_collection_status" >> /tmp/disk_cleanup.log
}

disk_size_check()
{
   retryCount=$1

   usep=`df -kh $WORK_PATH | grep -v "Filesystem" |awk '{print $5}'|sed 's/%//g'`
   if [ $usep -ge $DEFAULT_THRESHOLD_SIZE ] ; then
         echo "$retryCount. Running out of space \"$partition ($usep%)\"" >> /tmp/disk_cleanup.log
   else
       echo "$retryCount. Completed the cleanup during the bootup/runtime at `Timestamp`" >> /tmp/disk_cleanup.log
       echo "$WORK_PATH size $usep is OK to start" >> /tmp/disk_cleanup.log
       if [ $FLAG -eq 1 ];then
           if [ -f /tmp/disk_cleanup.log ] && [ ! -f /tmp/.standby ]; then
                cat /tmp/disk_cleanup.log >> /opt/logs/disk_cleanup.log
                cat /dev/null > /tmp/disk_cleanup.log
           fi
       fi
       exit 0
   fi
}

dirCleanupWith_latestFileBackup()
{
   path=$1
   if [ -d "$path" ]; then
       # latest dump backup
       latestDump=`ls -t $path | head -n 1`
       echo "Latest file: $latestDump" >> /tmp/disk_cleanup.log
       # place the latest dump back to the folder
       if [ "$latestDump" ]; then
            mv $path/$latestDump $PERSISTENT_PATH/
            # old dump cleanup
            rm -rf $path/*
            # place the latest dump back to the folder
            mv $PERSISTENT_PATH/$latestDump $path/$latestDump
       fi
   fi
}

dumpsCleanup()
{
   # first time cleanup
   disk_size_check $count
   dirCleanupWith_latestFileBackup "$CORE_BACK_PATH"
   echo "Deleted all corefiles from the corefiles_back folder" >> /tmp/disk_cleanup.log
   count=`counter $count`
   # second time cleanup
   disk_size_check $count
   dirCleanupWith_latestFileBackup "$CORE_PATH"
   echo "Deleted all corefiles from the corefiles folder" >> /tmp/disk_cleanup.log
   # third time cleanup
   count=`counter $count`
   disk_size_check $count
   dirCleanupWith_latestFileBackup "$MINIDUMPS_PATH"
   echo "Deleted all minidumps from the minidumps folder" >> /tmp/disk_cleanup.log
}

# Retain only the last packet capture
clearOlderPacketCaptures()
{
    #Remove *.pcap files from /opt/logs
    pcapCount=`ls $LOG_PATH/*.pcap* | wc -l`
    ## Retain last packet capture
    if [ $pcapCount -gt 0 ]; then
        lastEasPcapCapture="$LOG_PATH/eas.pcap"
        lastMocaPcapCapture="$LOG_PATH/moca.pcap"
        ## Back up last packet capture
        if [ -f $lastEasPcapCapture ]; then
            mv $lastEasPcapCapture $lastEasPcapCapture.bkp
        fi
        if [ -f $lastMocaPcapCapture ]; then
            mv $lastMocaPcapCapture $lastMocaPcapCapture.bkp
        fi
        rm -f $LOG_PATH/*.pcap
        if [ -f $lastEasPcapCapture.bkp ]; then
            mv $lastEasPcapCapture.bkp $lastEasPcapCapture
        fi
        if [ -f $lastMocaPcapCapture.bkp ]; then
            mv $lastMocaPcapCapture.bkp $lastMocaPcapCapture
        fi
        rm -f $LOG_PATH/eas.pcap.*
    fi
    
}


oldLogsFolderCleanup()
{
    oldestFolder=`ls -ldst /opt/logs/*-logbackup | tail -n 1`
    while [ "$oldestFolder" ]                
    do                                     
       deleteFolder=`echo ${oldestFolder##* }`
       if [ "$deleteFolder" ] && [ -d "$deleteFolder" ];then
            echo "Old Reboot Reasons Inside $deleteFolder ..!" >> /tmp/disk_cleanup.log
            grep -irn "Reboot" $deleteFolder | grep -v disk_cleanup.log | grep -v dcmscript.log | grep -v dca_output.txt | grep -v top_log.txt >> /tmp/disk_cleanup.log
            echo "Deleting the folder: $deleteFolder" >> /tmp/disk_cleanup.log
            rm -rf $deleteFolder
            count=`counter $count`
            disk_size_check $count                         
            oldestFolder=`ls -ldst /opt/logs/*-logbackup | tail -n 1`
       else
            oldestFolder=""
       fi
    done
}

logsCleanup()
{
         clearOlderPacketCaptures
         # fourth time cleanup
	 count=`counter $count`
         disk_size_check $count
         # delete older logs folder
         echo "Deleting older reboot cycle logs from the log backup folder" >> /tmp/disk_cleanup.log
         oldLogsFolderCleanup
         count=`counter $count`
         disk_size_check $count
         find $LOG_PATH -name "*.txt.5" -exec rm -rf {} \;
         find $LOG_PATH -name "*.log.5" -exec rm -rf {} \;
         echo "Deleted files with extensions *.txt.5 & *.log.5 from $LOG_PATH" >> /tmp/disk_cleanup.log
         # 8th time cleanup
         count=`counter $count`
         disk_size_check $count
         find $LOG_PATH -name "*.txt.4" -exec rm -rf {} \;
         find $LOG_PATH -name "*.log.4" -exec rm -rf {} \;
         echo "Deleted files with extensions *.txt.4 & *.log.4 from $LOG_PATH" >> /tmp/disk_cleanup.log
         # 9th time cleanup
         count=`counter $count`
         disk_size_check $count
         find $LOG_PATH -name "*.txt.3" -exec rm -rf {} \;
         find $LOG_PATH -name "*.log.3" -exec rm -rf {} \;
         echo "Deleted files with extensions *.txt.3 & *.log.3 from $LOG_PATH" >> /tmp/disk_cleanup.log
         # 10th time cleanup
         count=`counter $count`
         disk_size_check $count
         find $LOG_PATH -name "*.txt.2" -exec rm -rf {} \;
         find $LOG_PATH -name "*.log.2" -exec rm -rf {} \;
         echo "Deleted files with extensions *.txt.2 & *.log.2 from $LOG_PATH" >> /tmp/disk_cleanup.log
         # 11th time cleanup
         count=`counter $count`
         disk_size_check $count
         find $LOG_PATH -name "*.txt.1" -exec rm -rf {} \;
         find $LOG_PATH -name "*.log.1" -exec rm -rf {} \;
         echo "Deleted files with extensions *.txt.1 & *.log.1 from $LOG_PATH" >> /tmp/disk_cleanup.log

}

reduceFolderSize()
{
    path=$1
    size=$2
    optSize=`du -k $path | awk '{print $1}'| sed 's/[^0-9]*//g'`

    if [ $optSize -le $size ]; then
         return 0
    fi
    while [ $optSize -gt $size ]
    do
       oldFile=`ls -t $path | tail -1`
       echo "Old File: $oldFile" >> /tmp/disk_cleanup.log
       if [ -f $path/$oldFile ]; then rm -rf $path/$oldFile; fi
       optSize=`du -k $path | awk '{print $1}'| sed 's/[^0-9]*//g'`
       sleep 2
    done
}

# Execution Steps for DISK cleanup
command=`which lsof`
if [ "$command" ];then
     lsof | grep "logs.*\(deleted\)" > /tmp/.lsof_ouput
else
     echo "Missing the binary lsof" >> /tmp/disk_cleanup.log
fi

if [ "$DEVICE_TYPE" != "XHC1" ]; then
    echo "Memory Before Closed FD cleanup: `df -kh /opt`" >> /tmp/disk_cleanup.log
    if [ -s /tmp/.lsof_ouput ];then
        echo "We have open FDs even after deleting the files: `cat /tmp/.lsof_ouput`" >> /tmp/disk_cleanup.log
        while read line; do
            # Below condition ignores lines with TID column since cleaning up parent PIDs is enough
            if [ `echo $line | awk '{print NF}'` -eq 10 ]; then
                pid=`echo $line | awk '{print $2}'`
                openFD=`echo $line | awk '{print $4}' | tr -cd [:digit:]`
                echo /proc/$pid/fd/$openFD >> /tmp/disk_cleanup.log
                :> /proc/$pid/fd/$openFD
            fi
        done < /tmp/.lsof_ouput
        echo "Memory After Closed FD cleanup: `df -kh /opt`" >> /tmp/disk_cleanup.log
    fi
else
    uniq /tmp/.lsof_ouput > /tmp/.lsof_openfds
    rm -f /tmp/.lsof_ouput
    echo "Memory Before Closed FD cleanup: `df -kh /opt`" >> /tmp/disk_cleanup.log
    if [ -s /tmp/.lsof_openfds ];then
        echo "We have open FDs even after deleting the files: `cat /tmp/.lsof_openfds`" >> /tmp/disk_cleanup.log
        while read line; do
            pid=`echo $line | awk '{print $1}'`
            delfile=`echo $line | awk '{print $3}'`
            if [ -n "$pid" ] && [ -n "$delfile" ]; then
                openfds=`ls -alth /proc/$pid/fd | grep -i $delfile | tr -s " " | cut -d " " -f 9`
		if [ -n "$openfds" ] ;then
		    numopenFDs=`echo $openfds | awk '{print $NF}'`
                    fd=1
		    while [ $numopenFDs != 0 ] ;
                    do
                        openFD=`echo $openfds | awk -v p=$fd '{print $p}'`
                        if [ -n "$openFD" ]; then
                                echo /proc/$pid/fd/$openFD >> /tmp/disk_cleanup.log
                                :> /proc/$pid/fd/$openFD
                                fd=$((fd+1))
			fi
			numopenFDs=$((numopenFDs-1))
		    done
		fi
            fi
        done < /tmp/.lsof_openfds
        echo "Memory After Closed FD cleanup: `df -kh /opt`" >> /tmp/disk_cleanup.log
    fi
fi

NetflixDiskcache="/opt/netflix/nrd/gibbon/diskcache"
if [ -d "$NetflixDiskcache" ]; then
    size=$(du -s /opt/netflix/nrd/gibbon/diskcache/ | awk '{print $1}')
    # check if the used space is grater than 9MB (9216KB)
    if [ $size -ge 9216 ]; then
        # Delete all files under /opt/netflix/nrd/gibbon/diskcache
        echo "Memory consumed is $size which is more than threshold(9216kb), so deleting content of $NetflixDiskcache" >> /tmp/disk_cleanup.log
        rm -rf /opt/netflix/nrd/gibbon/diskcache/*
    fi
fi

#Only for HDD DISABLED device - RNG, check for JFFS Garbage collection status before checking disk size so that correct disk size is reported for script operations.
if [ "$DEVICE_NAME" = "RNG150" ]; then
     usep=`df -kh $WORK_PATH | grep -v "Filesystem" |awk '{print $5}'|sed 's/%//g'`
     echo "$WORK_PATH size is $usep before calling check_jffs_garbage_collection_status function" >> /tmp/disk_cleanup.log

     #check_jffs_garbage_collection_status for HDD_DISABLED device - RNGs
     check_jffs_garbage_collection_status
fi

if [ $FLAG -eq 0 ]; then
     echo "Bootup Time Cleanup..!" >> /tmp/disk_cleanup.log
     if [ -d /opt/lost+found ]; then
         echo "Clearing /opt/lost+found folder" >> /tmp/disk_cleanup.log
         rm -rf /opt/lost+found
     fi
     # BOOTUP cleanup
     dirCleanupWith_latestFileBackup "$CORE_BACK_PATH"
     # check and cleanup dumps inside the box
     dumpsCleanup
     # check and cleanup logs inside the box
     logsCleanup

     if [ "$DEVICE_TYPE" = "XHC1" ]; then
         # delete largest 3 files inside $LOG_PATH
         deleteMaxFile
         count=`counter $count`
         disk_size_check $count
         deleteMaxFile
         count=`counter $count`
         disk_size_check $count
         deleteMaxFile
         echo "Deleted the largest 3 log files from the logs path at boot time !" >> /tmp/disk_cleanup.log
         sync
     fi
elif [ $FLAG -eq 1 ]; then
     echo "Runtime Cleanup..!" >> /tmp/disk_cleanup.log
     # RUNTIME cleanup
     if [ "$HDD_ENABLED" = "true" ]; then
          # cleaning coredump backup area
          reduceFolderSize $CORE_BACK_PATH/ 2097152
          # cleaning coredump area
          reduceFolderSize $CORE_PATH/ 2097152
          # cleaning minidump area
          reduceFolderSize $MINIDUMPS_PATH/ 512000
          # check and cleanup dumps inside the box
          count=`counter $count`
          disk_size_check $count
          dumpsCleanup
          count=`counter $count`
          disk_size_check $count
          logsCleanup
     else
          count=`counter $count`
          disk_size_check $count
          dumpsCleanup
          count=`counter $count`
          disk_size_check $count
          logsCleanup
     fi
else
     echo "Runtime Error: Invalid input flag argument..!" >> /tmp/disk_cleanup.log
fi

# Final runtime/bootup cleanup
count=`counter $count`
disk_size_check $count
if [ "$DEVICE_TYPE" != "XHC1" ]; then
    # delete largest 3 files inside $LOG_PATH
    deleteMaxFile
    count=`counter $count`
    disk_size_check $count
    deleteMaxFile
    count=`counter $count`
    disk_size_check $count
    deleteMaxFile
    echo "Deleted the largest 3 log files from the logs path..!" >> /tmp/disk_cleanup.log
fi
count=`counter $count`
disk_size_check $count
echo "`Timestamp` CRITICAL ERROR, please check the /opt folder..!" >> /tmp/disk_cleanup.log
t2CountNotify "SYST_ERR_OPTFULL"

if [ $FLAG -eq 1 ];then
    if [ -f /tmp/disk_cleanup.log ] && [ ! -f /tmp/.standby ]; then
         cat /tmp/disk_cleanup.log >> /opt/logs/disk_cleanup.log
         cat /dev/null > /tmp/disk_cleanup.log
    fi
fi
exit 0


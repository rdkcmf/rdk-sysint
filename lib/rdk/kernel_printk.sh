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

if [ -f /etc/env_setup.sh ]; then
    . /etc/env_setup.sh
fi

MSG_LOG=$TEMP_LOG_PATH/pipe_dmesg_messages
FLAG=0

rm -rf $TEMP_LOG_PATH/pipe_dmesg_messages

if [ -f $RAMDISK_PATH/xfs_mount_dmesg.txt ]; then
        cp -a $RAMDISK_PATH/xfs_mount_dmesg.txt $LOG_PATH/
fi

if [ -f $PERSISTENT_PATH/.lightsleepKillSwitchEnable ]; then
	cd $LOG_PATH
	ln -s messages_printk.txt pipe_dmesg_messages
	cd -
else
    # lightsleep flag
	FLAG=1
	mkfifo $TEMP_LOG_PATH/pipe_dmesg_messages
fi

# Move the kernel log name to next log level 
rotate()
{
   inx=`expr $1 + 1`
   if [ -f $LOG_PATH/messages_printk_bak$1.txt ] ; then
       mv $LOG_PATH/messages_printk_bak$1.txt $LOG_PATH/messages_printk_bak$inx.txt 
   fi
}

index=9

# Set the name of the log file to next in loop from 9 to 1
while [ $index -gt 0 ]
do
    rotate $index
    index=`expr $index - 1`
done

# Set the name of the log file to first level
if [ -f $LOG_PATH/messages_printk.txt ]
then
	mv $LOG_PATH/messages_printk.txt $LOG_PATH/messages_printk_bak1.txt
fi 
match=0
while [ 1 ] 
do
    if [ -f /tmp/.standby ]; then          
         LOG_PATH=$TEMP_LOG_PATH
    else
         LOG_PATH=$LOG_PATH
    fi                           
    val=`date` 
    echo $val >> $LOG_PATH/messages_printk.txt

    if [ $FLAG -eq 1 ]; then
         count=`ps | grep $TEMP_LOG_PATH/pipe_dmesg_messages | grep -v grep | wc -l`
         if [ $count -eq 0 ]; then
              if [ ! -f /etc/os-release ]; then  
                  cat $TEMP_LOG_PATH/pipe_dmesg_messages >> $LOG_PATH/messages_printk.txt &
              fi
         fi
    fi 
                        
    #dmesg > /tmp/dmesg_temp.txt 
    #match=`cat /tmp/dmesg_temp.txt | grep 'Preemption'`
    #XONE-4017 to avoid audio-dropouts sync
    if [ ! -f /etc/os-release ]; then  
        dmesg -c >> $TEMP_LOG_PATH/pipe_dmesg_messages
    fi
    #if [ "$match" ]; then
     # sync
      #echo "***********SYNC********"
    # fi
    #rm /tmp/dmesg_temp.txt
    #XONE-4017 to avoid audio-dropouts sync
    sleep 30
done

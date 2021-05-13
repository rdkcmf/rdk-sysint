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

if [ "$LIGHTSLEEP_ENABLE" != "true" ] ; then exit; fi

if [ -f /opt/.disableLS ]; then
rm -rf /opt/.disableLS
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

# starting lightsleep configuration
if [ -f /opt/.lightsleepKillSwitchEnable -a $BUILD_TYPE = "dev" ]; then
	# lightsleep is disabled - then $TEMP_LOG_PATH is a symlink into /opt/logs on the HDD
	ln -s /opt/logs/ $TEMP_LOG_PATH
	ln -s /opt/.systime $TEMP_LOG_PATH/.systime
	sh $RDK_PATH/convertpipestoregularfiles.sh # creates symlinks from pipes to the actual log files 
else
	rm -rf $TEMP_LOG_PATH
	mkdir -p $TEMP_LOG_PATH

	# initialize lightsleep functionality
	sh $RDK_PATH/lightsleep_init.sh

	# set hdd spin down timer to infinity i.e. never spin down to begin with.
	# later during lightsleep mode we will change this so we spin this down
	hdparm -S 0 /dev/sda

	# start syslog logging
	if [ ! -p $TEMP_LOG_PATH/pipe_messages ] ; then
	    if [ -e $TEMP_LOG_PATH/pipe_messages ] ; then
		echo "Looks like a regular file called $TEMP_LOG_PATH/pipe_messages exists...deleting it." >> $TEMP_LOG_PATH/lightsleep.log
		rm $TEMP_LOG_PATH/pipe_messages
	    fi
	    echo "Pipe $TEMP_LOG_PATH/pipe_messages does not exist..let's created it here." >> $TEMP_LOG_PATH/lightsleep.log
            createPipeNode $TEMP_LOG_PATH/pipe_messages 
        fi

        cat $TEMP_LOG_PATH/pipe_messages >> /opt/logs/messages.txt &

# start executing lightsleep in the background
nice sh $RDK_PATH/lightsleep.sh &
fi

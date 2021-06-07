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

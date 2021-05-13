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

# creating symlinks from pipes to the actual files on the HDD
# note that pipes are regular files in this case

if [ -f /etc/os-release ]; then
     exit 0
fi

if [ "$LIGHTSLEEP_ENABLE" = "false" ]; then
     LOGFILE=$TEMP_LOG_PATH/lightsleep.log
     echo "Lightsleep: Converting pipes to regular files" >> $LOGFILE

     cd $TEMP_LOG_PATH

     # Delete the pipes if already exists (clean up)
     rm -rf $LOG_PATH/pipe_puma_messages
     rm -rf $LOG_PATH/pipe_receiver
     rm -rf $LOG_PATH/pipe_ocapri_log
     rm -rf $LOG_PATH/pipe_uimgr_log
     rm -rf $LOG_PATH/pipe_rf4ce_log
     rm -rf $LOG_PATH/pipe_top_log
     rm -rf $LOG_PATH/pipe_messages

     touch $LOG_PATH/messages-ecm.txt
     touch $LOG_PATH/receiver.log
     touch $LOG_PATH/ocapri_log.txt
     touch $LOG_PATH/uimgr_log.txt
     touch $LOG_PATH/rf4ce_log.txt
     touch $LOG_PATH/top_log.txt
     touch $LOG_PATH/messages.txt

     if [ "$SOC" != "BRCM" ];then
          touch $LOG_PATH/messages-puma.txt
          ln -s messages-puma.txt pipe_puma_messages
     else
          touch $LOG_PATH/messages-ecm.txt
          ln -s messages-ecm.txt pipe_puma_messages
     fi
     ln -s receiver.log pipe_receiver
     ln -s ocapri_log.txt pipe_ocapri_log
     ln -s uimgr_log.txt pipe_uimgr_log
     ln -s rf4ce_log.txt pipe_rf4ce_log
     ln -s top_log.txt pipe_top_log
     ln -s messages.txt pipe_messages
fi

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

. $RDK_PATH/commonUtils.sh
. $RDK_PATH/interfaceCalls.sh

if [ ! -f $RAMDISK_PATH/.uiMngrFlag ] || [ -f /tmp/.standby ]; then
     exit 0
fi
 
# Check the UIMNGR process
output=`processCheck uimgr_main`
if [ "$output" == "1" ]; then     
     echo "UIMngr process is killed.." 
     if [ "$HDD_ENABLED" = "false" ]; then
          if [[ -f $CORE_PATH/*core.prog_uimgr_main.signal_* ]] ; then
              waitForDumpCompletion 300
              TS=`date +%Y-%m-%d-%H-%M-%S`
              sh $RDK_PATH/uploadDumps.sh $TS 1
          fi
     fi
     echo "Rebooting due to UI Mngr crash" >> /opt/logs/uimgr_log.txt
     /rebootNow.sh -s UIMngrRecovery -o "Rebooting the box due to UI_Mngr process crash..."
     exit 1
fi

exit 0


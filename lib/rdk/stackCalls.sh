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

# Stack initialization for the box depending on the build type
hardwareInit()
{
      platform_config_app set_int platform.software.drivers.smd.sven_log_level_override 1
      # Commented out for XONE-7265 (mdvr performance issue)
      #csven hot enable all 
     
      # Back up the database
      if [ ! -f $PERSISTENT_PATH/PersistStorage.db ] ; then
          cp /etc/PersistStorage.db $PERSISTENT_PATH/
      fi

      #Copying the contents of dmesg
      $RDK_PATH/kernel_printk.sh &
}

hardwareResetCheck()
{
   if [ -f $PERSISTENT_PATH/.hrv_init.log ] ; then
        rm -rf $PERSISTENT_PATH/.hrv_init.log
        /hrvinit 30 1
   fi
 
   if [ -f $PERSISTENT_PATH/.hrv_cinit.log ] ; then
        rm -rf $PERSISTENT_PATH/.hrv_cinit.log
        /hrvcoldinit3.31 120 1
   fi
 
   /Reset > $TEMP_LOG_PATH/Reset.txt &
}

hdcp_Init()
{
  #XONE-1176
  if [ ! -f $PERSISTENT_PATH/.hdcp_srmerase_done ] ; then
      /usr/dtsbin/hdcp srmerase  < /yes.txt
      touch $PERSISTENT_PATH/.hdcp_srmerase_done
  fi
}

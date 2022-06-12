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

# Define logfiles and flags
KERNEL_RESET_REASON_VARIABLE=/sys/devices/platform/aml_pm/reset_reason

  RST_Reason=`cat $KERNEL_RESET_REASON_VARIABLE`
  case $RST_Reason in
  0)
  echo PreviousRebootReason:  power_on_reset!
  ;;
  1)
  echo PreviousRebootReason:  software_master_reset!
  ;;
  2)
  echo PreviousRebootReason:  factory_reset!
  ;;
  3)
  echo PreviousRebootReason:  update!
  ;;
  4)
  echo PreviousRebootReason:  fastboot!
  ;;
  5)
  echo PreviousRebootReason:  suspend_off!
  ;;
  6)
  echo PreviousRebootReason:  hibernate!
  ;;
  7)
  echo PreviousRebootReason:  bootloader!
  ;;
  8)
  echo PreviousRebootReason:  shutdown_reboot!
  ;;
  9)
  echo PreviousRebootReason:  rpmbp!
  ;;
  10)
  echo PreviousRebootReason:  quiescent reboot!
  ;;
  11)
  echo PreviousRebootReason:  crash_dumpg!
  ;;
  12)
  echo PreviousRebootReason:  kernel_panic!
  ;;
  13)
  echo PreviousRebootReason:  watchdog_timer_reset!
  ;;
  14)
  echo PreviousRebootReason:  quiescent recovery!
  ;;
  *)
  echo PreviousRebootReason:  unknown!
  ;;
  esac


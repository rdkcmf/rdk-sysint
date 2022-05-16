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
  echo PreviousRebootReason:  power_on_reset! > /dev/kmsg
  ;;
  1)
  echo PreviousRebootReason:  software_master_reset! > /dev/kmsg
  ;;
  2)
  echo PreviousRebootReason:  factory_reset! > /dev/kmsg
  ;;
  3)
  echo PreviousRebootReason:  update! > /dev/kmsg
  ;;
  4)
  echo PreviousRebootReason:  fastboot! > /dev/kmsg
  ;;
  5)
  echo PreviousRebootReason:  suspend_off! > /dev/kmsg
  ;;
  6)
  echo PreviousRebootReason:  hibernate! > /dev/kmsg
  ;;
  7)
  echo PreviousRebootReason:  bootloader! > /dev/kmsg
  ;;
  8)
  echo PreviousRebootReason:  shutdown_reboot! > /dev/kmsg
  ;;
  9)
  echo PreviousRebootReason:  rpmbp! > /dev/kmsg
  ;;
  10)
  echo PreviousRebootReason:  quiescent reboot! > /dev/kmsg
  ;;
  11)
  echo PreviousRebootReason:  crash_dumpg! > /dev/kmsg
  ;;
  12)
  echo PreviousRebootReason:  kernel_panic! > /dev/kmsg
  ;;
  13)
  echo PreviousRebootReason:  watchdog_timer_reset! > /dev/kmsg
  ;;
  14)
  echo PreviousRebootReason:  quiescent recovery! > /dev/kmsg
  ;;
  *)
  echo PreviousRebootReason:  unknown! > /dev/kmsg
  ;;
  esac


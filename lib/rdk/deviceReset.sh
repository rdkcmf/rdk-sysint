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

# input argument
resetArg=$1
resetFlag=$2

print_help() {
    echo "Arguments accepted are [ warehouse | factory | coldfactory | customer | personality | userfactory ]"
    exit 1
}


case "$resetArg" in
  "warehouse")
     resetType="warehouse-reset.sh"
     if [ "$resetFlag" == "--suppressReboot" ]; then
          touch /tmp/warehouse_reset_suppress_reboot
     fi
     ;;
  "factory")
     resetType="factory-reset.sh"
     ;;
  "coldfactory")
     resetType="coldfactory-reset.sh"
     ;;
  "customer")
     resetType="customer-reset.sh"
     ;;
  "personality")
     resetType="personality-reset.sh"
     ;;
  "userfactory")
     resetType="userfactory-reset.sh"
     ;;
  "WAREHOUSE_CLEAR")
     resetType="warehouse-reset.sh"
     if [ "$resetFlag" == "--suppressReboot" ]; then
          touch /tmp/warehouse_reset_suppress_reboot_clear
     fi
     ;;
   *)
     print_help
     ;;
esac

sh /lib/rdk/$resetType
exit 0


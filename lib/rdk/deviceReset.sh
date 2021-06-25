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


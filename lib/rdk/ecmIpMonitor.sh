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
. $RDK_PATH/utils.sh
. $RDK_PATH/commonUtils.sh

if [ -f $RAMDISK_PATH/.ecmIpFlag ] ; then
      rebootCount=`cat $RAMDISK_PATH/.ecmIpFlag`
      echo $((rebootCount+1)) > $RAMDISK_PATH/.ecmIpFlag
else
      echo 1 > $RAMDISK_PATH/.ecmIpFlag
fi

count=`cat $RAMDISK_PATH/.ecmIpFlag`

if [ $count -gt 3 ]; then
     rm -rf $RAMDISK_PATH/.ecmIpFlag
     echo "Rebooted the box 3 times for ECM IP "
     echo "Issue with ECM IP address"
     echo 10 > /opt/.reboot
     exit
else
     sleep 1800
     ret=`grep -irn "dhcp" $LOG_PATH/messages-puma.txt* | grep -irn "Set to the wan0 addr:" | wc -l`
     ret1=`grep -irn "Configuring IP stack 1:  IP Address = " $LOG_PATH/messages-ecm.txt* | wc -l`
     if [ $ret -eq 0 ] && [ $ret1 -eq 0 ]; then
          /rebootNow.sh -s "`basename $0`" -o "Rebooting the box due to not having ECM IP..."
     fi
fi


#!/bin/busybox sh
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
if [ "$DEVICE_TYPE" != "mediaclient" ]; then
     . /lib/rdk/commonUtils.sh
fi
if [ "$DEVICE_TYPE" = "mediaclient" ]; then
     . /lib/rdk/utils.sh
fi
if [ -f /etc/mount-utils/getConfigFile.sh ];then
      mkdir -p /tmp/.dropbear
      . /etc/mount-utils/getConfigFile.sh
fi
DROPBEAR_PARAMS_1="/tmp/.dropbear/dropcfg1$$"
DROPBEAR_PARAMS_2="/tmp/.dropbear/dropcfg2$$"
getConfigFile $DROPBEAR_PARAMS_1
getConfigFile $DROPBEAR_PARAMS_2

WAREHOUSE_ENV="$RAMDISK_PATH/warehouse_mode_active"
if [ -f /tmp/SSH.pid ]
then
   if [ -d /proc/`cat /tmp/SSH.pid` ]
   then
      echo "An instance of startSSH.sh is already running !!! Exiting !!!"
      exit 0
   fi
fi

echo $$ > /tmp/SSH.pid

ipAddress=""
checkForInterface()
{
   interface=$1
   if [ -f /tmp/estb_ipv6 ]; then
       ipAddress=`ip addr show dev $interface | grep -i global | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d'`
   else 
   	   ret=`ifconfig | grep $interface | grep -v $interface:0`
   	   if [ "$ret" ]; then
          ipAddress=`ifconfig $interface |  grep inet | grep -v inet6 | grep -v localhost | grep -v 127.0.0.1 |tr -s ' '| cut -d ' ' -f3 | sed -e 's/addr://g'`
       fi
  fi
}

#RFC check for MOCA SSH enable/not.
isMOCASSHEnable=$(/usr/bin/tr181Set -d  Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.MOCASSH.Enable 2>&1 > /dev/null)

echo "RFC_ENABLE_MOCASSH:$isMOCASSHEnable"

loop=1
address=""
# mediaclient code
if [ "$DEVICE_TYPE" = "mediaclient" ]; then
      while [ $loop -eq 1 ]
      do
           if [ "$WIFI_INTERFACE" ] && [ ! "$ipAddress" ];then
                 if [ -f /tmp/estb_ipv6 ];then
                       checkForInterface "$WIFI_INTERFACE"
                 else
                       checkForInterface "$WIFI_INTERFACE:0"
                 fi
                 if [ "$ipAddress" ]; then
                      loop=0
                 fi
           fi
           Interface=`getMoCAInterface`
           if [ ! "$ipAddress" ];then
                 if [ -f /tmp/estb_ipv6 ];then
                       checkForInterface "$Interface"
                 else
                       checkForInterface "$Interface:0"
                 fi
                 if [ "$ipAddress" ]; then
                      loop=0
                 fi
           fi
           if [ "$isMOCASSHEnable" = "true" ];then
               ipAddress+=" "
               ipAddress+=`ifconfig $MOCA_INTERFACE |grep 169.254.* |tr -s ' '| cut -d ' ' -f3 | sed -e 's/addr://g'`
           fi
           sleep 5
     done
     #Concatenating all ip addresses
     IP_ADDRESS_PARAM=""
     for i in $ipAddress;
     do
          IP_ADDRESS_PARAM+="-p $i:22 "
     done
     if [ -e /sbin/dropbear ] || [ -e /usr/sbin/dropbear ] ; then
          if [ -f /etc/os-release ];then
                /bin/systemctl set-environment DROPBEAR_PARAMS_1=$DROPBEAR_PARAMS_1
                /bin/systemctl set-environment DROPBEAR_PARAMS_2=$DROPBEAR_PARAMS_2
                /bin/systemctl set-environment IP_ADDRESS_PARAM="$IP_ADDRESS_PARAM"
          else
              dropbear -s -b /etc/sshbanner.txt -s -a -r $DROPBEAR_PARAMS_1 -r $DROPBEAR_PARAMS_2 $IP_ADDRESS_PARAM &
          fi
     fi
     exit 0
fi

startDropbear()
{
     ipAddress=$1
     echo --------- $interface got an ip $ipAddress starting dropbear service ---------
     if [ -f /etc/os-release ];then
          /bin/systemctl set-environment IP_ADDRESS=$ipAddress
          /bin/systemctl set-environment DROPBEAR_PARAMS_1=$DROPBEAR_PARAMS_1
          /bin/systemctl set-environment DROPBEAR_PARAMS_2=$DROPBEAR_PARAMS_2
     else
          dropbear -b /etc/sshbanner.txt -s -a -r $DROPBEAR_PARAMS_1 -r $DROPBEAR_PARAMS_2 -p $ipAddress:22 &
     fi
     echo "$ipAddress" > /tmp/.dropbearBoundIp
}

# non-mediaclient devices
while [ $loop -eq 1 ]
do
    estbIp=`getIPAddress`
    if [ "X$estbIp" == "X" ]; then
         sleep 15
    else
         if [ "$IPV6_ENABLED" = "true" ]; then
              if [ "Y$estbIp" != "Y$DEFAULT_IP" ] && [ -f $WAREHOUSE_ENV ]; then
                   startDropbear "$estbIp"
                   loop=0
              elif [ ! -f /tmp/estb_ipv4 ] && [ ! -f /tmp/estb_ipv6 ]; then
                   sleep 15
              elif [ "Y$estbIp" == "Y$DEFAULT_IP" ] && [ -f /tmp/estb_ipv4 ]; then
                   #echo "waiting for IP ..."
                   sleep 15
              elif [ "Y$estbIp" == "Y$DEFAULT_IP" ] && [ -f /tmp/estb_ipv6 ]; then
                   #echo "waiting for IP ..."
                   sleep 15
              else
                   startDropbear "$estbIp"
                   loop=0
              fi
         else
              if [ "Y$estbIp" == "Y$DEFAULT_IP" ]; then
                   #echo "waiting for IP ..."
                   sleep 15
              else
                   startDropbear "$estbIp"
                   loop=0
              fi
	 fi
    fi
done

exit 0

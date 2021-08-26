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

if [ -f /etc/device.properties ];then
  . /etc/device.properties
fi

if [ -f /etc/include.properties ];then
  . /etc/include.properties
fi

if [ -f /etc/env_setup.sh ]; then
    . /etc/env_setup.sh
fi

VENDOR_SPEC_FILE="/etc/udhcpc.vendor_specific"
OPTION_FILE="/tmp/vendor_spec.txt"
DHCP_CONFIG_FILE="/etc/dibbler/client.conf"
DHCP_CONFIG_FILE_RFS="/etc/dibbler/client_back.conf"
DIBBLER_LOG="$LOG_PATH/dibbler.log"

if [ ! -f /etc/os-release ];then
    DHCP_CONFIG_FILE_RUNTIME="/tmp/dibbler/client.conf"
else
    DHCP_CONFIG_FILE_RUNTIME="/etc/dibbler/client.conf"
fi
DHCP_CONFIG_FILE_TMP="/tmp/dibbler/client-tmp.conf"
RDK_PATH="/lib/rdk"

if [ "x$MODEL_NUM" == "xPX001AN" ];then
    interface=$DEFAULT_ESTB_INTERFACE
else
    interface=$ESTB_INTERFACE
fi

if [ ! -f /etc/dibbler/radvd.conf ];then touch /etc/dibbler/radvd.conf; fi
if [ ! -f /etc/dibbler/radvd.conf.old ];then touch /etc/dibbler/radvd.conf.old; fi

if [ -f /etc/os-release ];then
     if [ ! -f /tmp/dibbler/radvd.conf ];then touch /tmp/dibbler/radvd.conf; fi
     if [ ! -f /tmp/dibbler/radvd.conf.old ];then touch /tmp/dibbler/radvd.conf.old; fi
fi

HOSTNAME=`hostname`
if [ -f /etc/hosts ]; then
    grep -i "::1 $HOSTNAME" /etc/hosts > /dev/null
    if [ $? -ne 0 ]; then
        echo "::1 $HOSTNAME" >> /etc/hosts
    fi
else
    echo "::1 $HOSTNAME" >> /etc/hosts
fi

updateOptInfo()
{
  opt_val=$1
  subopt_num=$2
  subopt_len=`echo ${#opt_val}`
  subopt_len_h=`printf "%04x\n" $subopt_len`;
  subopt_val_h=`echo -n $opt_val | hexdump -e '13/1 "%02x"'`
  echo -n $subopt_num$subopt_len_h$subopt_val_h >> $OPTION_FILE
  return
}

stb_mac=`ifconfig -a $interface | grep $interface | tr -s ' ' | cut -d ' ' -f5 | tr -d '\r\n' | tr '[a-z]' '[A-Z]'`
stb_mac=$(echo $stb_mac | sed 's/://g')
if [ -f $OPTION_FILE ]; then
        rm -rf $OPTION_FILE
fi
if [ -f /etc/os-release ];then
  # Wait and retry undil vendor specific options are available 
  retry=0
  MAX_RETRY=60
  vendorModelOption=`grep -i 'SUBOPTION9' $VENDOR_SPEC_FILE | cut -d ' ' -f3`
  while [ -z "$vendorModelOption" ]
  do
    retry=$((retry + 1))
    echo "`date` Vendor specific option file is empty!!! Retrying ..." >> $DIBBLER_LOG
    sleep 2
    vendorModelOption=`grep -i 'SUBOPTION9' $VENDOR_SPEC_FILE | cut -d ' ' -f3`
    if [ $retry -gt $MAX_RETRY ]; then
      echo "`date` Vendor specific option file is empty after $retry retry attempts. Exitting !!!" >> $DIBBLER_LOG
      exit 1
    fi
  done
fi
echo "option 0016 hex 0x0000118b000C4F70656E4361626C65322E31" >> $OPTION_FILE
echo -n "option 0017 hex 0x0000118b" >> $OPTION_FILE
     while read line
     do
	       opt_num=`echo $line | cut -f1 -d" "`
               opt_val=`echo $line | cut -f2 -d" "`
               case "$opt_num" in
                    "SUBOPTION2")
                            subopt_num="0002"
                            updateOptInfo $opt_val $subopt_num
                            ;;
                    "SUBOPTION3")
                            subopt_num="0003"
                            updateOptInfo $opt_val $subopt_num
                            ;;
                    "SUBOPTION4")
                            subopt_num="0004"
                            updateOptInfo $opt_val $subopt_num
                            ;;
                    "SUBOPTION5")
                            subopt_num="0005"
                            updateOptInfo $opt_val $subopt_num
                            ;;
                    "SUBOPTION6")
                            subopt_num="0006"
			    updateOptInfo $opt_val $subopt_num
                            ;;
                    "SUBOPTION7")
                            subopt_num="0007"
                            updateOptInfo $opt_val $subopt_num
                            ;;
                    "SUBOPTION8")
                            subopt_num="0008"
                            updateOptInfo $opt_val $subopt_num
                            ;;
                    "SUBOPTION9")
                            subopt_num="0009"
                            updateOptInfo $opt_val $subopt_num
                            ;;
                    "SUBOPTION10")
                            subopt_num="000a"
                            updateOptInfo $opt_val $subopt_num
                            ;;

                      *)
                            ;;
               esac;
  	done < "$VENDOR_SPEC_FILE"
 subopt_num="0024"
 subopt_len="0006"
 opt_val=$stb_mac
 echo -n $subopt_num$subopt_len$opt_val >> $OPTION_FILE
# updateOptInfo $opt_val $subopt_num
 mkdir -p /tmp/dibbler
 if [ -f "$DHCP_CONFIG_FILE_RUNTIME" ]; then
       rm -rf $DHCP_CONFIG_FILE_RUNTIME
 fi
 if [ -f "$DHCP_CONFIG_FILE_TMP" ]; then
     rm -rf $DHCP_CONFIG_FILE_TMP
 fi
 sed '$d' $DHCP_CONFIG_FILE_RFS > $DHCP_CONFIG_FILE_TMP
 cat $OPTION_FILE >> $DHCP_CONFIG_FILE_TMP
 echo >> $DHCP_CONFIG_FILE_TMP
 echo "}" >> $DHCP_CONFIG_FILE_TMP
 echo 'script "/lib/rdk/add_hostname.sh"' >> $DHCP_CONFIG_FILE_TMP
if [  -f /etc/os-release ];then
  if [ "$interface" ] && [ -f $DHCP_CONFIG_FILE_TMP ];then
    sed -i "s/RDK-ESTB-IF/${interface}/g" $DHCP_CONFIG_FILE_TMP
  fi
fi

if [ "x$DEVICE_NAME" != "xRNG150" ]; then
    # Applies only for platforms which requests for a prefix deligate
    echo "downlink-prefix-ifaces $MOCA_INTERFACE" >> $DHCP_CONFIG_FILE_TMP
fi

 cat $DHCP_CONFIG_FILE_TMP > $DHCP_CONFIG_FILE_RUNTIME

if [ "x$DEVICE_NAME" == "xRNG150" ] && [ ! -f /etc/os-release ]; then
    sed -i "/^ *pd/d" $DHCP_CONFIG_FILE_RUNTIME
fi


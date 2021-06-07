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

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

DNS_SERVERS=$*
LOG_FILE="/opt/logs/named.log"

DNS64_SERVER1=`tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.DNS64Proxy.Server1 2>&1`
DNS64_SERVER2=`tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.DNS64Proxy.Server2 2>&1`
DNS64_SERVER3=`tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.DNS64Proxy.Server3 2>&1`
DNS64_SERVER4=`tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.DNS64Proxy.Server4 2>&1`
RFC_BIND_ENABLED=`tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.DNS64Proxy.Enable 2>&1`
APPENDER_STR="{ \n clients { any; };\n exclude { 64:FF9B::/96; ::ffff:0000:0000/96; }; \n suffix ::; \n };"
DNS64_STR=""

if [ "x$DNS64_SERVER1" != "x" ]; then
	DNS64_STR="$DNS64_STR \ndns64 $DNS64_SERVER1 $APPENDER_STR"
fi

if [ "x$DNS64_SERVER2" != "x" ]; then
	DNS64_STR="$DNS64_STR \ndns64 $DNS64_SERVER2 $APPENDER_STR"
fi

if [ "x$DNS64_SERVER3" != "x" ]; then
	DNS64_STR="$DNS64_STR \ndns64 $DNS64_SERVER3 $APPENDER_STR"
fi

if [ "x$DNS64_SERVER4" != "x" ]; then
	DNS64_STR="$DNS64_STR \ndns64 $DNS64_SERVER4 $APPENDER_STR"
fi

if [ "x$BIND_ENABLED" = "xtrue" -a "x$RFC_BIND_ENABLED" = "xtrue" ]; then
	BUILD_CONF_PATH="/tmp/named.conf.options"
	# Refresh the options again. Since resolver config can change while box is running.
	# Added the following to handle that case.
	/bin/umount /etc/bind/named.conf.options
	rm -f $BUILD_CONF_PATH
	/sbin/mount-copybind  $BUILD_CONF_PATH /etc/bind/named.conf.options
	sed -i "s#\/\/OPT#$DNS_SERVERS#g" $BUILD_CONF_PATH
	if [ "x$DNS64_STR" != "x" ];  then
		sed -i "s#\/\/DNS64#$DNS64_STR#g" $BUILD_CONF_PATH
		echo "DNS64 Servers are Configured" >>$LOG_FILE
	else
		echo "DNS64 Servers not Configured" >>$LOG_FILE
	fi
	cat /tmp/named.conf.options >/etc/bind/named.conf.options
	if [ -f /usr/sbin/named -o -f /media/apps/bind-dl/usr/sbin/named ];then
		pkill -HUP named
		systemctl stop dnsmasq.service
		systemctl restart named.service
		echo "`/bin/timestamp` Bind Support is enabled, named is used for  DNS Resolutions." >> $LOG_FILE
                t2CountNotify "SYST_INFO_DNSNamed"
        else
		echo "`/bin/timestamp` Bind Support is enabled, named binary is not present, DnsMasq is used in DNS Resolutions." >> $LOG_FILE
        fi
else
	# This is to make sure atleast dnsmasq runs even if it fails initially. or some switch happened inbetween.
	echo "Bind Support is not enabled" >> $LOG_FILE
	systemctl stop named.service
	systemctl restart dnsmasq.service
fi


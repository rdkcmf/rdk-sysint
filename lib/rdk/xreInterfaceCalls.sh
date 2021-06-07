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
. /etc/device.properties

if [ -f /lib/rdk/interfaceCalls.sh ];then
    . /lib/rdk/interfaceCalls.sh
fi

manufacture=$MANUFACTURE
if [ "$RECEIVER_PLAT_TYPE" ];then
     device=$RECEIVER_PLAT_TYPE
else
     device=$BOX_TYPE
fi
version=$BUILD_VERSION

plat="${MANUFACTURE//_}_${RECEIVER_PLAT_TYPE//_}_${BUILD_VERSION//_}"
buildType=$BUILD_TYPE

getXreURL()
{
    xreUrl=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.xre-receiver.xreUrl 2>&1)

    if [ -f $PERSISTENT_PATH/receiver.conf ] && [ "$BUILD_TYPE" != "prod" ] ; then
        urlString=`grep -v '^[[:space:]]*#' /opt/receiver.conf | head -n 1 | tr -d '[ \t]'`
        if [ "$urlString" != "" ]; then
            tmpString=$urlString
            # parse protocol, 5 is length of the longest supported protocol name: i.e https, http, xre, xres, ws, wss,file.
            parsedProtocol=$(echo $tmpString | awk -F'://' '{ if ( NF >= 2 && length($1) <= 5 ) print $1; else print "xre"; }')
            # remove parsed protocol
            tmpString=$(echo $tmpString | sed "s,^$parsedProtocol://,,")
            # get host:port
            parsedHostAndPort=$(echo $tmpString | awk -F"/" '{ print $1; }')
            # Fix for supporting literal IPv6 Addresses format in URL's
            # Adding escape characters for metacharacters "["  "]" in pattern containing host and port
            tmpParsedHostAndPort="${parsedHostAndPort//\[/\\[}"
            tmpParsedHostAndPort="${tmpParsedHostAndPort//\]/\\]}"
            # remove parsed host:port
            parsedApp=$(echo $tmpString | sed "s,^$tmpParsedHostAndPort,,")

            # additional checking for absence of ' ' in Host+Port part
            parsedHostAndPort=$(echo $parsedHostAndPort | awk '{ if ( index($0, " " ) == 0 ) print $0; else print ""; }')

            if [[ x"$parsedHostAndPort" == x"" && x"$parsedProtocol" != x"file" ]] || [[ x"$parsedProtocol" == x"" ]]; then
                xreUrl="xre://ccpapp-dt-v001-i.dt.ccp.cable.comcast.com:10001/shell" #xre ip
            elif [[ x"$parsedApp" == x"/" ]] || [[ x"$parsedApp" == x"" ]]; then
                xreUrl="${parsedProtocol}://${parsedHostAndPort}/shell"
            else
                xreUrl="${parsedProtocol}://${parsedHostAndPort}${parsedApp}"
            fi
        fi
    fi
    echo ${xreUrl}
}

getFirstConnectURL()
{
    firstConnectUrl=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.xre-receiver.firstConnectUrl 2>&1)

    if [ -f $PERSISTENT_PATH/receiver.conf ] && [ "$BUILD_TYPE" != "prod" ] ; then
        urlString=`grep -v '^[[:space:]]*#' $PERSISTENT_PATH/receiver.conf`
        if [ "$urlString" != "" ]; then
            tmpString=$urlString
            # parse protocol, 5 is length of the longest supported protocol name: i.e https, http, xre, xres, ws, wss,file.
            parsedProtocol=$(echo $tmpString | awk -F'://' '{ if ( NF >= 2 && length($1) <= 5 ) print $1; else print "xre"; }')
            # remove parsed protocol
            tmpString=$(echo $tmpString | sed "s,^$parsedProtocol://,,")
            # get host:port
            parsedHostAndPort=$(echo $tmpString | awk -F"/" '{ print $1; }')
            # Fix for supporting literal IPv6 Addresses format in URL's
            # Adding escape characters for metacharacters "["  "]" in pattern containing host and port
            tmpParsedHostAndPort="${parsedHostAndPort//\[/\\[}"
            tmpParsedHostAndPort="${tmpParsedHostAndPort//\]/\\]}"
            # remove parsed host:port
            parsedApp=$(echo $tmpString | sed "s,^$tmpParsedHostAndPort,,")

            # additional checking for absence of ' ' in Host+Port part
            parsedHostAndPort=$(echo $parsedHostAndPort | awk '{ if ( index($0, " " ) == 0 ) print $0; else print ""; }')

            if [[ x"$parsedHostAndPort" == x"" && x"$parsedProtocol" != x"file" ]] || [[ x"$parsedProtocol" == x"" ]]; then
                firstConnectUrl="wss://xre.ccp.xcal.tv:10601/shell"
            elif [[ x"$parsedApp" == x"/" ]] || [[ x"$parsedApp" == x"" ]]; then
                firstConnectUrl="${parsedProtocol}://${parsedHostAndPort}/shell"
            else
                firstConnectUrl="${parsedProtocol}://${parsedHostAndPort}${parsedApp}"
            fi
        fi
    fi
    echo ${firstConnectUrl}
}

# Return system uptime in seconds
Uptime()
{
    cat /proc/uptime | awk '{ split($1,a,".");  print a[1]; }'
}

getProxyIp()
{
	 if [ -f $PERSISTENT_PATH/xreproxy.conf ] &&  [ "$BUILD_TYPE" != "prod" ]; then
          grep -v '^[[:space:]]*#' $PERSISTENT_PATH/xreproxy.conf | cut -d ':' -f1
     else
          echo 10.253.96.38 #Proxy IP
     fi
}

getProxyPort()
{
	 if [ -f $PERSISTENT_PATH/xreproxy.conf ] &&  [ "$BUILD_TYPE" != "prod" ]; then
          grep -v '^[[:space:]]*#' $PERSISTENT_PATH/xreproxy.conf | cut -d ':' -f2
     else
          echo 8080 #Proxy port
     fi
}
#specific to xi3, DO NOT delete when doing MERGE !!!
installWebcamera()
{
	export brcm_pts_45k_base=y

	export ALSA_CONFIG_PATH=/usr/local/bin/alsa/alsa.conf
	export ALSA_PLUGIN_PATH=/usr/local/lib/alsa-lib
					     
	mkdir /dev/snd
	mknod /dev/snd/controlC0 c 116 0
	mknod /dev/snd/pcmC0D0c c 116 24
	mknod /dev/snd/timer c 116 33
	     
	cp /mnt/nfs/env/skype/asound.conf /etc/
								     
	insmod /mnt/nfs/env/skype/uvcvideo_97429.ko
}

cleanupXRE()
{   
	cp $TEMP_LOG_PATH/app_status.log $LOG_PATH/app_status_backup.log
	$RDK_PATH/backupDumps.sh Receiver
} 

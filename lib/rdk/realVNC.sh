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


if [ -f /etc/device.properties ]; then
    . /etc/device.properties
fi

APPLN_HOME_PATH=""
VNC_APP_DIR=/lib/rdk/realvnc
RDM_DLPATH=/media/apps/co-pilot/lib/rdk/realvnc
TMP_DLPATH=/tmp/co-pilot/lib/rdk/realvnc

checkAppData()
{
    if [ -e $RDM_DLPATH ]; then
        APPLN_HOME_PATH=$RDM_DLPATH
    elif [ -e $TMP_DLPATH ]; then
        APPLN_HOME_PATH=$TMP_DLPATH
    fi
}

# check RDM feature enabled/disabled
getCoPilotAppLocation()
{
if [ -f $VNC_APP_DIR/libvncbearer*.so ];then
    echo "RDM feature is disabled, library part of firmware" >> /opt/logs/rssServer.log
    APPLN_HOME_PATH=$VNC_APP_DIR
else
    echo "RDM feature is enabled, get the downloaded location" >> /opt/logs/rssServer.log
    checkAppData
    if [ ! -z "$APPLN_HOME_PATH" ]; then
        echo "Co-Pilot components are found in path $APPLN_HOME_PATH" >> /opt/logs/rssServer.log
    else
        echo "Co-Pilot components not found in $RDM_DLPATH and $TMP_DLPATH path" >> /opt/logs/rssServer.log
        echo "Calling Retry for Co-Pilot App download..." >> /opt/logs/rssServer.log
        sh /usr/bin/apps_rdm.sh "co-pilot"
        sleep 1
        checkAppData
        if [ ! -z "$APPLN_HOME_PATH" ]; then
           echo "Co-pilot App Downloaded in $APPLN_HOME_PATH" >> /opt/logs/rssServer.log
        else
           echo "Co-pilot App Download failed...!!!" >> /opt/logs/rssServer.log
        fi
    fi
fi
}

# Defaulting to mipsel architecture
VNC_EXECUTABLE="vnc-Comcast-mipsel"

case "$CPU_ARCH" in
  *mipsel* )
    VNC_EXECUTABLE="vnc-Comcast-mipsel"
    POLLTIME="1000"
    ;;
  *x86* )
    VNC_EXECUTABLE="vnc-Comcast-x86"
    POLLTIME="500"
    ;;
  *ARM* )
    VNC_EXECUTABLE="vnc-Comcast-armcortex"
    POLLTIME="1000"
    ;;
esac

usage()
{
  echo "USAGE:   realVNC.sh {start|stop} {args}"
}
MODE=$1
case $MODE in
            h)
               usage
               exit 1
               ;;
        start)
               pid=`pidof $VNC_EXECUTABLE`
               if [ -n "$pid" ]
               then
                   echo "RSS Server is already running. Killing the already running instance. " >> /opt/logs/rssServer.log
                   kill -9 $pid
               fi
               if [ ! -f /etc/os-release ]; then
                 if [ -e /mnt/nfs/env/realvnc/$VNC_EXECUTABLE ]
                 then
                   current_dir=`pwd`
                     cd /mnt/nfs/env/realvnc
                     export LD_PRELOAD=/usr/local/lib/libdbus-1.so:/usr/local/lib/libglib-2.0.so
                     export LD_LIBRARY_PATH=/mnt/nfs/env/realvnc:/usr/local/lib:$LD_LIBRARY_PATH;
                   echo -e "\n \n ******* Starting RSS Server *******" >> /opt/logs/rssServer.log
                   ./$VNC_EXECUTABLE $2 -P=$POLLTIME >> /opt/logs/rssServer.log 2>&1 &
                   pid=`pidof "$VNC_EXECUTABLE"`
                   if [ -n $pid ]
                   then
                       echo $pid > /tmp/RealVNC.pid
                   fi

                   cd $current_dir
                 else
                     echo "/mnt/nfs/env/realvnc/$VNC_EXECUTABLE is not present" >> /opt/logs/rssServer.log
                 fi
               else
                 #Check the folder location of VNC libraries
                 echo "Checking APPLN_HOME_PATH for Co-Pilot App location..." >> /opt/logs/rssServer.log
                 getCoPilotAppLocation
                 if [ -e ${APPLN_HOME_PATH}/$VNC_EXECUTABLE ]
                 then
                   current_dir=`pwd`
                     cd ${APPLN_HOME_PATH}
                     export LD_PRELOAD=/usr/lib/libdbus-1.so.3:/usr/lib/libglib-2.0.so.0
                     export LD_LIBRARY_PATH=/usr/lib:/usr/bin:$LD_LIBRARY_PATH;
                   echo -e "\n \n ******* Starting RSS Server *******" >> /opt/logs/rssServer.log
                   ./$VNC_EXECUTABLE $2 -P=$POLLTIME >> /opt/logs/rssServer.log 2>&1 &
                   pid=`pidof "$VNC_EXECUTABLE"`
                   if [ -n $pid ]
                   then
                       echo $pid > /tmp/RealVNC.pid
                   fi
                   cd $current_dir
                 else
                     echo "${APPLN_HOME_PATH}/$VNC_EXECUTABLE is not present" >> /opt/logs/rssServer.log
                 fi
               fi
               ;;

         stop)
               pid=`pidof $VNC_EXECUTABLE`
               if [ -n "$pid" ]
               then
                   echo -e " ******* Stopping RSS Server *******" >> /opt/logs/rssServer.log
                   kill -9 $pid
               fi
               ;;
         status)
               pid=`pidof $VNC_EXECUTABLE`
               if [ -n "$pid" ]
               then
                   echo 1
               else
                   echo 2
               fi
               ;;
        *)
               usage
               exit
               ;;
esac

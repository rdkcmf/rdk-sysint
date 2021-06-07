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
if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
     . /lib/rdk/getSecureDumpStatus.sh
fi

if [ -f /etc/os-release ]; then
    exit 0
fi

# Checking the dependency module before startup
nice sh $RDK_PATH/iarm-dependency-checker "CHROOT"

if [ "$SOC" = "BRCM" ];then
     if [ ! -d /opt/persistent ]; then mkdir -p /opt/persistent ; fi
     if [ ! -d /opt/persistent/adobe ]; then mkdir -p /opt/persistent/adobe ; fi
     chmod -R 777 /opt/persistent/adobe
     mount --bind /opt/persistent /opt/restricted/opt/persistent
     if [ ! -d /opt/drm ]; then mkdir -p /opt/drm ; fi
     chmod -R 777 /opt/drm
     mount --bind /opt/drm /opt/restricted/opt/drm
     chgrp restrictedgroup /opt/restricted/opt/drm
     mkdir -p /opt/restricted/opt/persistent
     mkdir -p /opt/restricted/opt/persistent/adobe
     mount --rbind /opt/persistent /opt/restricted/opt/persistent
     mount --rbind /opt/persistent/adobe /opt/restricted/opt/persistent/adobe
     chgrp restrictedgroup /opt/restricted/opt/persistent
     chgrp restrictedgroup /opt/restricted/opt/persistent/adobe
     chmod g+w /opt/restricted/opt/persistent/adobe
     mkdir -p /opt/restricted/tmp/mnt/diska3
     mount --bind /tmp/mnt/diska3 /opt/restricted/tmp/mnt/diska3

     mkdir -p /opt/restricted/mnt/memory
     mount --rbind /mnt/memory /opt/restricted/mnt/memory
     chgrp restrictedgroup -Rh /opt/restricted/lib/*
     if [ -d /mnt ]; then
         mkdir -p /opt/restricted/mnt
         mount --bind  /mnt /opt/restricted/mnt
         chgrp restrictedgroup /opt/restricted/mnt
     fi
     if [ -d /mnt/nvram1 ]; then
         mkdir -p /opt/restricted/mnt/nvram1
         mount --bind /mnt/nvram1 /opt/restricted/mnt/nvram1
         chgrp -R restrictedgroup /opt/restricted/mnt/nvram1/*
         chmod g+w /opt/restricted/mnt/nvram1/*
     fi
     if [ -d /opt/QT ]; then
         chgrp restrictedgroup -R /opt/restricted/opt/QT
     fi
     if [ -d /etc/fonts ]; then
         mkdir -p /opt/restricted/etc/fonts
         mount --bind  /etc/fonts /opt/restricted/etc/fonts
         chgrp restrictedgroup /opt/restricted/etc/fonts
     fi
     if [ -d /var/run/dbus ]; then
         mkdir -p /opt/restricted/var/run/dbus/
         mount --rbind /var/run/dbus/ /opt/restricted/var/run/dbus
         chgrp restrictedgroup -R /opt/restricted/var/run/dbus
     fi
fi

mkdir -p /opt/restricted

mkdir -p /opt/restricted/lib/rdk
mount --rbind  /lib/rdk /opt/restricted/lib/rdk

mkdir -p /opt/restricted/opt
mount --bind /opt /opt/restricted/opt
chown -R restricteduser:restrictedgroup /opt/restricted/opt

mkdir /opt/restricted/bin
mount --bind /bin /opt/restricted/bin

mkdir -p /opt/restricted/sysint
mount --bind /sysint /opt/restricted/sysint

mkdir -p /opt/restricted/tmp
mount --bind /tmp /opt/restricted/tmp
chown -R restricteduser:restrictedgroup /opt/restricted/tmp

#mkdir -p /opt/restricted/tmp/mnt/diska3
#mount --bind /tmp/mnt/diska3 /opt/restricted/tmp/mnt/diska3

mkdir -p /opt/restricted/opt/.adobe
mount --bind /opt/.adobe /opt/restricted/opt/.adobe
chown -R restricteduser:restrictedgroup /opt/restricted/opt/.adobe

mkdir -p /opt/restricted/opt/.macromedia
mount --bind /opt/.macromedia /opt/restricted/opt/.macromedia
chown -R restricteduser:restrictedgroup /opt/restricted/opt/.macromedia

mkdir -p /opt/restricted/lib
mount --bind /lib /opt/restricted/lib

mkdir -p /opt/restricted/mnt/nfs/bin
mount --bind  /mnt/nfs/bin /opt/restricted/mnt/nfs/bin

mkdir -p /opt/restricted/mnt/nfs/env
mount --bind  /mnt/nfs/env /opt/restricted/mnt/nfs/env

mkdir -p /opt/restricted/proc
mount --bind  /proc /opt/restricted/proc

mkdir -p /opt/restricted/sys
mount --bind  /sys /opt/restricted/sys

mkdir -p /opt/restricted/dev
mount --bind  /dev /opt/restricted/dev
chown -Rh restricteduser:restrictedgroup /opt/restricted/dev

mkdir -p /opt/restricted/dev/shm
mount --bind  /dev/shm /opt/restricted/dev/shm
chown -Rh restricteduser:restrictedgroup /opt/restricted/dev/shm

mkdir -p /opt/restricted/usr
mount --bind  /usr /opt/restricted/usr

mkdir -p /opt/restricted/usr/bin
mount --bind  /usr/bin /opt/restricted/usr/bin
                                                     
mkdir -p /opt/restricted/sbin                         
mount --bind  /sbin /opt/restricted/sbin              
                                                      
mkdir -p /opt/restricted/var/logs                     
mount --bind  /var/logs /opt/restricted/var/logs      
chgrp -Rh restrictedgroup /opt/restricted/var/logs
chmod g+w /opt/restricted/var/logs
#chown -R restricteduser:restrictedgroup /opt/restricted/var/logs

mkdir -p /opt/restricted/opt/logs
mount --bind  /opt/logs /opt/restricted/opt/logs
chgrp -Rh restrictedgroup /opt/restricted/opt/logs
#chown -R restricteduser:restrictedgroup /opt/restricted/opt/logs
                                                      
mkdir -p /opt/restricted/usr/local/lib                
mount --bind  /usr/local/lib /opt/restricted/usr/local/lib
                                                          
mkdir -p /opt/restricted/usr/local/Qt                     
mount --bind  /usr/local/Qt /opt/restricted/usr/local/Qt  
                                                          
mkdir -p /opt/restricted/usr/lib                          
mount --bind  /usr/lib /opt/restricted/usr/lib            

mkdir -p /opt/restricted/usr/local/bin                          
mount --bind  /usr/local/bin /opt/restricted/usr/local/bin            

mkdir -p /opt/restricted/etc                              
mount --bind  /etc /opt/restricted/etc                    

if [ -d /var/run/dbus ]; then
    mkdir -p /opt/restricted/var/run/dbus
    mount --bind  /var/run/dbus /opt/restricted/var/run/dbus
    chown -Rh restricteduser:restrictedgroup /opt/restricted/var/run/dbus
fi

if [ -d /.ssh ]; then 
    mkdir -p /opt/restricted/.ssh
    mount --bind /.ssh /opt/restricted/.ssh
fi

if [ -d /etc/.ssh ]; then
    mkdir -p /opt/restricted/etc/.ssh
    mount --bind  /etc/.ssh /opt/restricted/etc/.ssh
fi

chown restricteduser:restrictedgroup /opt/restricted/dev/fusion*
chown restricteduser:restrictedgroup /opt/restricted/tmp/fusion.*
if [ ! -f /opt/logs/receiver.log ]; then
     touch /opt/logs/receiver.log
fi

if [ ! -f /opt/logs/core_log.txt ]; then
     touch /opt/logs/core_log.txt
fi
touch /var/logs/receiver.log
touch /opt/logs/app_status.log
chgrp restrictedgroup /opt/logs/app_status.log
chmod g+w /opt/logs/app_status.log
chgrp restrictedgroup /var/logs/receiver.log
chmod g+w /var/logs/receiver.log
chown restricteduser:restrictedgroup /opt/restricted/opt/logs/receiver.log
chown restricteduser:restrictedgroup /opt/logs/core_log.txt
chown restricteduser:restrictedgroup /opt/restricted/opt/xupnp/
chown -R restricteduser:restrictedgroup /opt/restricted/opt/QT
chown restricteduser:restrictedgroup /opt/restricted$CORE_PATH
chown restricteduser:restrictedgroup /opt/restricted$MINDUMPS_PATH
if [ ! -d /opt/restricted$CORE_BACK_PATH ]; then
    	mkdir -p /opt/restricted$CORE_BACK_PATH
	chown -R restricteduser:restrictedgroup /opt/restricted$CORE_BACK_PATH
fi
chown restricteduser:restrictedgroup /opt/restricted/dev/avcap_core
chown restricteduser:restrictedgroup /opt/restricted/var/logs/pipe_receiver
#chgrp restrictedgroup -Rh /opt/restricted/var/logs/*
chown restricteduser:restrictedgroup /opt/restricted/tmp/csmedia_msr*
chown restricteduser:restrictedgroup /opt/restricted/tmp/video1_msr*
                                                          
# File copies                                             
cp /bin/timestamp /opt/restricted                             
cp /lib/rdk/lightsleepCopy.sh /opt/restricted                     
chgrp restrictedgroup -Rh /opt/restricted/lib/rdk/*
cp /version.txt /opt/restricted
cp /SetEnv.sh /opt/restricted
cp /rebootNow.sh /opt/restricted

chown restricteduser:restrictedgroup /opt/restricted/bin/timestamp
chown restricteduser:restrictedgroup /opt/restricted/lightsleepCopy.sh
chown restricteduser:restrictedgroup /opt/restricted/version.txt
chown restricteduser:restrictedgroup /opt/restricted/SetEnv.sh
chown restricteduser:restrictedgroup /opt/restricted/rebootNow.sh

export ALSA_CONFIG_PATH=/usr/local/bin/alsa/alsa.conf
export ALSA_PLUGIN_PATH=/usr/local/lib/alsa-lib
                                             
mkdir /dev/snd
mknod /dev/snd/controlC0 c 116 0
mknod /dev/snd/pcmC0D0c c 116 24
mknod /dev/snd/timer c 116 33
cp /mnt/nfs/env/skype/asound.conf /etc/
insmod /mnt/nfs/env/skype/uvcvideo_97429.ko

chown restricteduser:restrictedgroup /dev/snd/*

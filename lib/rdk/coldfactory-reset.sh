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


. /etc/device.properties

# clear pairing data
if [ -f /usr/bin/ctrlmTestApp ]; then
    ctrlmTestApp -n all -f ;          # unpair controllers
    /bin/systemctl stop ctrlm-main ;  # shut down controlMgr
    rm -rf /opt/ctrlm.sql /opt/ctrlm.back
    rm -rf /opt/gp/
    rm -rf /opt/gp500/
    rm -rf /opt/hal_nvm.back
    rm -rf /opt/tiNVfile.nv /opt/tiNVfile.tmp; # remove all NVM files
fi
   
# persistent data cleanup	
if [ -d /opt/persistent ]; then
    find /opt/persistent -mindepth 1 -maxdepth 1 ! -name 'store-mode-video' -exec rm -rf {} \;
fi
if [ -d /tmp/mnt/diska3/persistent/dvr ];then
    rm -rf /tmp/mnt/diska3/persistent/dvr 
fi

if [ "$DEVICE_TYPE" = "mediaclient" ];then
     if [ -f /lib/rdk/ubi-volume-cleanup.sh ];then
         sh /lib/rdk/ubi-volume-cleanup.sh "PERSISTENT_jffs2"
     fi
     sleep 1
fi

# whitebox data cleanup
if [ -d /opt/www/whitebox ]; then
     rm -rf /opt/www/whitebox/*
fi

# authservice data cleanup
if [ -d /opt/www/authService ]; then
     rm -rf /opt/www/authService/*
fi

if [ "$DEVICE_TYPE" = "mediaclient" ];then
     if [ -f /lib/rdk/ubi-volume-cleanup.sh ];then
          sh /lib/rdk/ubi-volume-cleanup.sh "WWW_jffs2"
     fi
     sleep 1
fi

# opt data cleanup
if [ -d /opt/logs ]; then
     rm -rf /opt/logs/*
fi
if [ -d /var/logs ]; then
     rm -rf /var/logs/*
fi

if [ -f /opt/mpeenv.ini ];then rm -rf /opt/mpeenv.ini ; fi
if [ -f /opt/rmfconfig.ini ];then rm -rf /opt/rmfconfig.ini ; fi
if [ -f /opt/swupdate.conf ];then rm -rf /opt/swupdate.conf ; fi
if [ -f /opt/xreproxy.conf ];then rm -rf /opt/xreproxy.conf ; fi
if [ -f /opt/debug.ini ];then rm -rf /opt/debug.ini ; fi
if [ -f /opt/dcm.properties ];then rm -rf /opt/dcm.properties ; fi
if [ -f /opt/rfc.properties ];then rm -rf /opt/rfc.properties ; fi
if [ -f /opt/storageMgr.conf ];then rm -rf /opt/storageMgr.conf ; fi
if [ -f /opt/xdevice_hybrid.conf ];then rm -rf /opt/xdevice_hybrid.conf ; fi
if [ -f /opt/xdiscovery.conf ];then rm -rf /opt/xdiscovery.conf ; fi
if [ -f /opt/xdevice.conf ];then rm -rf /opt/xdevice.conf ; fi
if [ -f /opt/gzdisabled ];then rm -rf /opt/gzdisabled ; fi
if [ -f /opt/enable_delia_dual ];then rm -rf /opt/enable_delia_dual ; fi
if [ -f /opt/hddEnable ];then rm -rf /opt/hddEnable ; fi
if [ -f /opt/tmtryoptout ];then rm -rf /opt/tmtryoptout ; fi

if [ -f /opt/secure/Apparmor_blocklist ];then rm -rf /opt/secure/Apparmor_blocklist ; fi

# Kill the nrdPluginApp first, else the /opt/netflix would be re-created by this process.
killall -s SIGKILL nrdPluginApp
if [ -d /opt/netflix ]; then rm -rf /opt/netflix; fi
if [ -d "${SD_CARD_MOUNT_PATH}/netflix" ]; then rm -rf "${SD_CARD_MOUNT_PATH}/netflix"; fi
# BT data cleanup
if [ -d /opt/lib/bluetooth ]; then rm -rf /opt/lib/bluetooth; fi

if [ -e /lib/rdk/device-specific-reset.sh ]; then
    echo "ColdFactory Reset: Clean configs specific ti the device"
    /lib/rdk/device-specific-reset.sh "COLDFACTORY" "CLEAN-CONFIG"
fi

if [ "$DEVICE_TYPE" = "mediaclient" ];then
     # Erasing the override configurations
     if [ -f /opt/no-upnp ]; then
          rm -rf /opt/no-upnp
     fi
     rm -rf /opt/*.conf
     if [ -f /lib/rdk/ubi-volume-cleanup.sh ];then
         # Opt partition cleanup
         sh /lib/rdk/ubi-volume-cleanup.sh "OPT_jffs2"
         sleep 1
         # PDRI image cleanup
         sh /lib/rdk/ubi-volume-cleanup.sh "PDRI-cleanup"
         sleep 1
         # Banls cleanup
         sh /lib/rdk/ubi-volume-cleanup.sh "scrubAllBanks"
     fi

else
     rm -rf /opt/QT/*
     rm -rf /tmp/mnt/diska3/persistent/.has_livestream_client
     rm -rf /opt/persistent/ds/hostData*
     sleep 1
     echo 0 > /opt/.rebootFlag
     if [ -f /SetEnv.sh ] ; then
          source /SetEnv.sh
     fi
     touch /tmp/.warehouse-reset
     echo `/bin/timestamp` ---- Rebooting due to Cold Factory Reset process ---- >> /opt/logs/ocapri_log.txt
     echo "`/bin/timestamp` Triggered from ($0) after Cold factory Reset..!" >> /opt/.rebootInfo.log
     /hrvcoldinit3.31 120 2

fi
exit 0


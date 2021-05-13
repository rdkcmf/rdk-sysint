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
    rm -rf /opt/persistent/*
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
# Kill the nrdPluginApp first, else the /opt/netflix would be re-created by this process.
killall -s SIGKILL nrdPluginApp
if [ -d /opt/netflix ]; then rm -rf /opt/netflix; fi
if [ -d "${SD_CARD_MOUNT_PATH}/netflix" ]; then rm -rf "${SD_CARD_MOUNT_PATH}/netflix"; fi
# BT data cleanup
if [ -d /opt/lib/bluetooth ]; then rm -rf /opt/lib/bluetooth; fi

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


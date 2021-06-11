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

echo "Factory Reset:Clearing Remote Pairing Data"
# clear pairing data
if [ -f /usr/bin/ctrlmTestApp ]; then
    ctrlmTestApp -n all -f ;                  # unpair controllers
    /bin/systemctl stop ctrlm-main.service ;  # shut down controlMgr
    rm -rf /opt/ctrlm.sql /opt/ctrlm.back
    rm -rf /opt/gp/
    rm -rf /opt/gp500/
    rm -rf /opt/hal_nvm.back
    rm -rf /opt/tiNVfile.nv /opt/tiNVfile.tmp; # remove all NVM files
fi

if [ -f /etc/os-release ];then
    echo "Factory Reset:Stopping the services"
    if [ "$DEVICE_NAME" != "LLAMA" ] && [ "$DEVICE_NAME" != "PLATCO" ]; then
      if [ "$CONTAINER_SUPPORT" == "true" ] && [ ! -f /opt/lxc_service_disabled ]; then
          /bin/systemctl stop lxc.service
      else
          /bin/systemctl stop xre-receiver.service
      fi
    fi
    #/bin/systemctl stop dbus.service
    /bin/systemctl stop rmfstreamer.service
    /bin/systemctl stop vitalprocess-info.timer
    /bin/systemctl stop mocastatuslogger.timer
    /bin/systemctl stop dump-log.timer
    /bin/systemctl stop logrotate.timer
    /bin/systemctl stop av-status-logger.timer
    /bin/systemctl stop xupnp.service
    if [ "$WHITEBOX_ENABLED" == "true" ]; then
        /bin/systemctl stop whitebox.service
    fi
    /bin/systemctl stop sysmgr.service
    /bin/systemctl stop swupdate.service
    /bin/systemctl stop storagemgrmain.service
    /bin/systemctl stop socprovisioning.service
    /bin/systemctl stop rf4ce.service
    /bin/systemctl stop moca.service
    #/bin/systemctl stop mfrlibapp.service
    /bin/systemctl stop lighttpd.service
    /bin/systemctl stop irmgr.service
    /bin/systemctl stop dump-backup.service
    /bin/systemctl stop dnsmasq.service
    /bin/systemctl stop authservice.service
    /bin/systemctl stop dibbler.path
    /bin/systemctl stop udhcp.path
    /bin/systemctl stop dcm-log.service
    /bin/systemctl stop syslog.socket
    /bin/systemctl stop dump-log.timer
    /bin/systemctl stop wpeframework.service
    if [ "$DOBBY_ENABLED" == "true" ]; then
        /bin/systemctl stop dobby.service
    fi
    if [ "$DEVICE_TYPE" != "mediaclient" ];then
        /bin/systemctl stop cecdaemon.service
        /bin/systemctl stop cecdevmgr.service
        /bin/systemctl stop xcal-device.path
        /bin/systemctl stop xcal-device.service
        /bin/systemctl stop runsnmp.service
        /bin/systemctl stop snmpd.service
        /bin/systemctl stop runpod.service       
        /bin/systemctl stop vodclientapp.service
        /bin/systemctl stop wsproxy.service
        /bin/systemctl stop udhcp.service
        /bin/systemctl stop trm-srv.service
        /bin/systemctl stop rf-status-logger.service
        /bin/systemctl stop power-state-monitor.service
        /bin/systemctl stop ecmlogger.service
        /bin/systemctl stop deviceupdatemgr.service
        /bin/systemctl stop udpsvd.service
        /bin/systemctl stop syssnmpagent.service
    else
        /bin/systemctl stop dsmgr.service
        #/bin/systemctl stop iarmbusd.service
        /bin/systemctl stop playreadycdmi
        /bin/systemctl stop fog
        /bin/systemctl stop tr69agent.service
        if [ "$WIFI_SUPPORT" == "true" ];
        then
            /bin/systemctl stop wpa_supplicant.service
        fi
    fi
fi

echo "Factory Reset:Starting file cleanUp"
# persistent data cleanup
if [ -d /opt/persistent ]; then rm -rf /opt/persistent/* ; fi
if [ -d /tmp/mnt/diska3/persistent ];then rm -rf /tmp/mnt/diska3/persistent/*; fi
if [ -f /tmp/mnt/diska3/OCAP_LSV ];then rm -rf /tmp/mnt/diska3/OCAP_LSV;fi

# whitebox data cleanup
if [ -d /opt/www/whitebox ]; then rm -rf /opt/www/whitebox/* ; fi
if [ -d /mnt/nvram2/whitebox ]; then rm -rf /mnt/nvram2/whitebox/* ; fi
if [ -d /mnt/nvram2/.www_backup/whitebox ]; then rm -rf /mnt/nvram2/.www_backup/whitebox/*; fi

# authservice data cleanup
if [ -d /opt/www/authService ]; then rm -rf /opt/www/authService/*; fi
if [ -d /mnt/nvram2/authService ]; then rm -rf /mnt/nvram2/authService/*; fi

# opt data cleanup
if [ -d /opt/logs ]; then rm -rf /opt/logs/*; fi
if [ -d /var/logs ]; then rm -rf /var/logs/*; fi

# Erasing the override configurations
rm -rf /opt/*.conf
rm -rf /opt/*.conf.*
rm -rf /opt/*.ini
if [ -f /opt/no-upnp ]; then rm -rf /opt/no-upnp; fi
if [ -f /opt/dcm.properties ];then rm -rf /opt/dcm.properties ; fi
if [ -f /opt/gzdisabled ];then rm -rf /opt/gzdisabled ; fi
if [ -f /opt/enable_delia_dual ];then rm -rf /opt/enable_delia_dual ; fi
if [ -f /opt/hddEnable ];then rm -rf /opt/hddEnable ; fi
if [ -d /opt/wifi ]; then rm -rf /opt/wifi/*;fi
if [ -d /opt/secure/wifi ]; then rm -rf /opt/secure/wifi/*;fi
if [ -f /opt/DCMscript.out ]; then rm -f /opt/DCMscript.out;fi
if [ -d /opt/QT ]; then rm -rf /opt/QT/*;fi
if [ -f /opt/comcast-acs ]; then rm -f /opt/comcast-acs;fi
if [ -d /opt/corefiles ]; then rm -rf /opt/corefiles/*;fi
if [ -d /opt/corefiles_back ]; then rm -rf /opt/corefiles_back/*;fi
if [ -d /opt/secure/corefiles ]; then rm -rf /opt/secure/corefiles/*;fi
if [ -d /opt/secure/corefiles_back ]; then rm -rf /opt/secure/corefiles_back/*;fi
if [ -d /opt/.gstreamer ]; then rm -rf /opt/.gstreamer; fi
if [ -d /opt/ds ]; then rm -rf /opt/ds/*;fi
if [ -f /opt/hn_service_settings.conf ]; then rm -f /opt/hn_service_settings.conf;fi
if [ -f /opt/lof.eth1 ]; then rm -f /opt/lof.eth1;fi
if [ -f /opt/logFileBackup ]; then rm -f /opt/logFileBackup;fi
if [ -d /opt/minidumps ]; then rm -rf /opt/minidumps/*;fi
if [ -d /opt/secure/minidumps ]; then rm -rf /opt/secure/minidumps/*;fi
if [ -f /opt/temp.json ]; then rm -f /opt/temp.json;fi
if [ -e /opt/tr69agent-db ]; then rm -rf /opt/tr69agent-db; fi
if [ -e /opt/secure/tr69agent-db ]; then rm -rf /opt/secure/tr69agent-db; fi
if [ -f /opt/uimgr_settings.bin ]; then rm -f /opt/uimgr_settings.bin;fi
if [ -f /opt/uploadSTBLogs.out ]; then rm -f /opt/uploadSTBLogs.out;fi
if [ -d /opt/upnp ]; then rm -rf /opt/upnp/*;fi
if [ -L /opt/www/htmldiag ]; then rm -f /opt/www/htmldiag;fi
if [ -f /opt/tmtryoptout ];then rm -rf /opt/tmtryoptout ; fi

# DRM data cleanup
PROVISION_PROPERTIES=/etc/provision.properties
RT_PROTOCOL_VERSION=$(sed -n 's/^RT_PROTOCOL_VERSION=//p' $PROVISION_PROPERTIES)
if [ ! -z $RT_PROTOCOL_VERSION ]; then
  . ${PROVISION_PROPERTIES}
      if [ ! -z "$TYPES" ]; then
          DRM_TYPES=TYPES[@]
          DRM_TYPES=("${!DRM_TYPES}")
          for drm_type in ${DRM_TYPES[*]}; do
            if [ ! -z "$drm_type" ]; then
                ARRAY_DIRS=$drm_type
                DRM_DIRS=$ARRAY_DIRS[@]
                DRM_DIRS=("${!DRM_DIRS}")
                for drm_dir in ${DRM_DIRS[*]}; do
                  if [ ! -z "$drm_dir" ]; then
                    if [ -d $drm_dir ]; then
                      rm -rf "${drm_dir:?}/"*
                    fi
                  fi
                done
            fi
          done
      fi
else
  if [ -d /opt/drm ]; then rm -rf /opt/drm/*;fi
fi

# RFC data cleanup
if [ -d /opt/RFC ]; then rm -rf /opt/RFC; fi
if [ -d /opt/secure/RFC ]; then rm -rf /opt/secure/RFC; fi

# Kill the nrdPluginApp first, else the /opt/netflix would be re-created by this process.
killall -s SIGKILL nrdPluginApp
if [ -d /opt/netflix ]; then rm -rf /opt/netflix; fi
if [ -d "${SD_CARD_MOUNT_PATH}/netflix" ]; then rm -rf "${SD_CARD_MOUNT_PATH}/netflix"; fi
# BT data cleanup
if [ -d /opt/lib/bluetooth ]; then rm -rf /opt/lib/bluetooth; fi

# remove all apps data only if path is non empty and exits
if [ -d "$SD_CARD_APP_MOUNT_PATH" ]; then
    find "$SD_CARD_APP_MOUNT_PATH" -mindepth 1 -maxdepth 1 ! -name 'store-mode-video' -exec rm -rf {} \;
fi
if [ -d "$HDD_APP_MOUNT_PATH" ]; then rm -rf $HDD_APP_MOUNT_PATH/*; fi

if [ "$DEVICE_TYPE" = "mediaclient" ];then
     WIFI_BIN_LOC=${WIFI_BIN_LOC:=/usr/bin/}

    # Wifi data cleanup
     if [ -f $WIFI_BIN_LOC/mfr_wifiEraseAllData ]; then
         $WIFI_BIN_LOC/mfr_wifiEraseAllData
     fi
     
     if [ "$SD_CARD_TYPE" = "EMMC" ]; then
         if [ -f /lib/rdk/emmc_format.sh ]; then
             sh /lib/rdk/emmc_format.sh
         fi
     else
         if [ -f /lib/rdk/ubi-volume-cleanup.sh ];then

             if [ "$SDCARD" != "" ]; then
                 sh /lib/rdk/ubi-volume-cleanup.sh $SDCARD
             fi
             
             if [ "$PERSISTENT_PARTITION" != "" ]; then
                 sh /lib/rdk/ubi-volume-cleanup.sh $PERSISTENT_PARTITION
             fi

             if [ "$AUTH_DATA_PARTITION" != "" ]; then
                 sh /lib/rdk/ubi-volume-cleanup.sh $AUTH_DATA_PARTITION
             fi

             if [ "$OPT_PARTITION" != "" ]; then
                 sh /lib/rdk/ubi-volume-cleanup.sh $OPT_PARTITION
             fi
         
             if [ "$TRANSFER_PARTITION" != "" ]; then
                 sh /lib/rdk/ubi-volume-cleanup.sh $TRANSFER_PARTITION
             fi
         
         fi
     fi
     
     if [ -f /lib/rdk/ubi-volume-cleanup.sh ];then
         sh /lib/rdk/ubi-volume-cleanup.sh "scrubAllBanks"
     fi

     sleep 1
     sh /rebootNow.sh -s FactoryReset -o "Rebooting the box after Factory Reset Process..."

else

     sleep 1
     echo 0 > /opt/.rebootFlag
     echo `/bin/timestamp` ---- Rebooting due to Factory Reset process ---- >> /opt/logs/ocapri_log.txt
     /hrvcoldinit3.31 120 2
fi

exit 0


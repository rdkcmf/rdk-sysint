#!/bin/bash
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2022 RDK Management, LLC. All rights reserved.
# ============================================================================

setupContainerBundle()
{
  SRC_DIR=$1
  PLUGIN_NAME=$2
  USR=$3
  GRP=$4

  CONTAINER_BUNDLE_DIR=/opt/persistent/rdkservices/
  PLUGIN_DIR=${CONTAINER_BUNDLE_DIR}/${PLUGIN_NAME}
  DST_DIR=${PLUGIN_DIR}/Container

  if [ ! -f "${SRC_DIR}/config.json" ]; then
    echo "`Timestamp` OCI bundle not present in firmware - ${SRC_DIR}/config.json not found" >> $LOGFILE
    return 1
  fi

  # if this is first time we open as container
  if [ ! -d "${PLUGIN_DIR}/storage" ]; then
    # move all data including credentials to storage (so it is later avalible inside container)
    # include hidden .* files but not linux built in "." and ".." directories
    mkdir -p "${PLUGIN_DIR}/storage"
    mv  "${PLUGIN_DIR}/".[!.]* "${PLUGIN_DIR}/storage/"
    mv  "${PLUGIN_DIR}/"* "${PLUGIN_DIR}/storage/"
  fi

  # Copy bundle only if different
  if [ -f "${DST_DIR}/config-dobby.json" ]; then
    image_sum=$(md5sum ${SRC_DIR}/config.json | cut -d' ' -f1)
    opt_sum=$(md5sum ${DST_DIR}/config-dobby.json | cut -d' ' -f1)

    if [ "x$image_sum" != "x$opt_sum" ]; then
      echo "`Timestamp` Copying OCI bundle for $2 from firmware as config.json doesn't match expected" >> $LOGFILE
      rm -rf "${DST_DIR:?}/"*
      cp "${SRC_DIR}/config.json" "${DST_DIR}"
      cp -R "${SRC_DIR}/rootfs_dobby" "${DST_DIR}"
    else
      echo "`Timestamp` Valid OCI bundle found for $2, not recreating" >> $LOGFILE
    fi
  else
    echo "`Timestamp` No OCI bundle for $2 found in opt, copying from firmware" >> $LOGFILE
    mkdir -p "${DST_DIR}"
    rm -rf "${DST_DIR:?}/"*
    cp "${SRC_DIR}/config.json" "${DST_DIR}"
    cp -R "${SRC_DIR}/rootfs_dobby" "${DST_DIR}"
  fi

  # Set permissions on the container bundle directory
  chmod +x "${CONTAINER_BUNDLE_DIR}"

  chmod -R 744 "${PLUGIN_DIR}"
  chown -R ${USR}:${GRP} "${PLUGIN_DIR}"

  echo "`Timestamp` setupContainerBundle() for $2 done" >> $LOGFILE
  return 0
}

moveStorageFromContainer()
{
  PLUGIN_NAME=$1

  CONTAINER_BUNDLE_DIR=/opt/persistent/rdkservices/
  PLUGIN_DIR=${CONTAINER_BUNDLE_DIR}/${PLUGIN_NAME}
  DST_DIR=${PLUGIN_DIR}/Container

  # if container exists
  if [ -d "${DST_DIR}" ]; then
    # move all data including credentials from storage (so it is later avalible outside container)
    mv "${PLUGIN_DIR}/storage/"* "${PLUGIN_DIR}/"
    mv "${PLUGIN_DIR}/storage/".[!.]* "${PLUGIN_DIR}/"
    rm -rf "${DST_DIR:?}"
    rm -rf "${PLUGIN_DIR:?}/storage"
  fi
}

setContainerPermissions()
{
  # Set generic container permissions
  # All containers should run in the dobbyapp group

  # Set permissions applicable to all containers
  mkdir /tmp/OCDM
  chown -R root:dobbyapp /tmp/OCDM
  chown -R root:dobbyapp /opt/drm
  chmod -R g+rwx /opt/drm

  chown root:dobbyapp /opt/persistent/rdkservices/
  chmod 770 /opt/persistent/rdkservices/

  # ERM
  chown root:vpu /run/resource
  chmod 775 /run/resource
}

enableNetflixContainer()
{
  FLASH_OCI_BUNDLE_DIR=/container/netflix

  if setupContainerBundle ${FLASH_OCI_BUNDLE_DIR} "Netflix-0" "netflix" "dobbyapp"; then
    # Set permissions as necessary for this container
    echo "`Timestamp` Fixing permissions for Netflix container" >> $LOGFILE

    mkdir /run/Netflix/
    chown -R dobbyapp:dobbyapp /run/Netflix

    mkdir -p /opt/netflix/network
    chown -R netflix:netflix /opt/netflix
    chown -R netflix:netflix /opt/drm/netflix
    chown netflix:netflix /tmp/.deviceDetails*

    chown -R root:netflix /opt/logs/rfcscript.log
    chmod g+rw /opt/logs/rfcscript.log
    
    echo "eth0" > /tmp/dial_interface_container
  else
    echo "`Timestamp` Failed to setup Netflix container" >> $LOGFILE
  fi
}

enableCobaltContainer()
{
  FLASH_OCI_BUNDLE_DIR=/container/cobalt

  if setupContainerBundle ${FLASH_OCI_BUNDLE_DIR} "Cobalt-0" "cobalt" "dobbyapp"; then
    # Set permissions as necessary for this container
    echo "`Timestamp` Fixing permissions for Cobalt container" >> $LOGFILE

    mkdir /run/Cobalt/
    chown -R dobbyapp:dobbyapp /run/Cobalt
  else
    echo "`Timestamp` Failed to setup Cobalt container" >> $LOGFILE
  fi
}

enableWebkitContainer()
{
  HTMLAPP_FIRMWARE_BUNDLE=/container/htmlapp
  LIGHTNINGAPP_FIRMWARE_BUNDLE=/container/lightningapp
  SAD_FIRMWARE_BUNDLE=/container/sad

  # Not currently enabling residentapp - see OTTX-18990

  if setupContainerBundle ${HTMLAPP_FIRMWARE_BUNDLE} "HtmlApp" "dobbyapp" "dobbyapp"; then
    # Set permissions as necessary for this container
    echo "`Timestamp` Fixing permissions for HtmlApp container" >> $LOGFILE

    # Set htmlapp-specific permissions
    mkdir /run/HtmlApp/
    chown -R dobbyapp:dobbyapp /run/HtmlApp
  else
    echo "`Timestamp` Failed to setup HtmlApp container" >> $LOGFILE
  fi

  if setupContainerBundle ${LIGHTNINGAPP_FIRMWARE_BUNDLE} "LightningApp" "dobbyapp" "dobbyapp"; then
    # Set permissions as necessary for this container
    echo "`Timestamp` Fixing permissions for LightningApp container" >> $LOGFILE

    # Set lightningapp-specific permissions
    mkdir /run/LightningApp/
    chown -R dobbyapp:dobbyapp /run/LightningApp
  else
    echo "`Timestamp` Failed to setup LightningApp container" >> $LOGFILE
  fi

  if setupContainerBundle ${SAD_FIRMWARE_BUNDLE} "SearchAndDiscoveryApp" "dobbyapp" "dobbyapp"; then
    # Set permissions as necessary for this container
    echo "`Timestamp` Fixing permissions for SearchAndDiscoveryApp container" >> $LOGFILE

    # Set SaD-specific permissions
    mkdir /run/SearchAndDiscoveryApp/
    chown -R dobbyapp:dobbyapp /run/SearchAndDiscoveryApp
  else
    echo "`Timestamp` Failed to setup SearchAndDiscoveryApp container" >> $LOGFILE
  fi
}

. /etc/include.properties
. $RDK_PATH/utils.sh

LOGFILE=/opt/logs/container-setup.log

# Netflix container mode
netflixContainerEnabled=$(getRFCValueForTR181Param Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.Dobby.Netflix.Enable)
if [ -n "${netflixContainerEnabled}" ] && [ "${netflixContainerEnabled}" = "true" ]; then
  echo "`Timestamp` Netflix running in container mode" >> $LOGFILE
  setContainerPermissions
  enableNetflixContainer
else
  echo "`Timestamp` Netflix not running in container mode" >> $LOGFILE
  moveStorageFromContainer "Netflix-0"
fi

# Cobalt container mode
cobaltContainerEnabled=$(getRFCValueForTR181Param Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.Dobby.Cobalt.Enable)
if [ -n "${cobaltContainerEnabled}" ] && [ "${cobaltContainerEnabled}" = "true" ]; then
  echo "`Timestamp` Cobalt running in container mode" >> $LOGFILE
  setContainerPermissions
  enableCobaltContainer
else
  echo "`Timestamp` Cobalt not running in container mode" >> $LOGFILE
  moveStorageFromContainer "Cobalt-0"
fi

# WPE Container mode
wpeContainerEnabled=$(getRFCValueForTR181Param Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.Dobby.WPE.Enable)
if [ -n "${wpeContainerEnabled}" ] && [ "${wpeContainerEnabled}" = "true" ]; then
  echo "`Timestamp` WPE running in container mode" >> $LOGFILE
  setContainerPermissions
  enableWebkitContainer
else
  echo "`Timestamp` WPE not running in container mode" >> $LOGFILE
  moveStorageFromContainer "HtmlApp"
  moveStorageFromContainer "LightningApp"
  moveStorageFromContainer "SearchAndDiscoveryApp"
fi
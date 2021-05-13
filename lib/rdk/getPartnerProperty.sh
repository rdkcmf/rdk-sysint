#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2018 RDK Management, LLC. All rights reserved.
# ============================================================================
#
##################################################################
## Script to Partner Bootstrap Configuration
## Updates the following information in the settop box
##    list of features that are enabled or disabled
##    if feature configuration is effective immediately
##    updates startup parameters for each feature
##    updates the list of variables in a single file
## Author: Milorad
##################################################################

if [ $# != 1 ] ; then
    echo "[BP] Usage: $0 <property_name>" >> /opt/logs/rfcscript.log
    exit 1
fi

cgPDf=0

useNewBC=`tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.BootstrapConfig.Enable 2>&1 > /dev/null`
if [ "$useNewBC" =  "true" ]; then
    if [ "$1" = "ntpHost" ]; then
        result=`tr181 Device.Time.NTPServer1 2>&1 > /dev/null`
        echo $result
    elif [ "$1" = "partnerName" ]; then
        result=`tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Bootstrap.PartnerName 2>&1 > /dev/null`
        echo $result
    elif [ "$1" = "partnerProductName" ]; then
        result=`tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Bootstrap.PartnerProductName 2>&1 > /dev/null`
        echo $result
    else
        cgPDf=1
    fi
    echo "[BP] Returning through tr181 call for $1, result=$result" >> /opt/logs/rfcscript.log
else
    cgPDf=1
fi

if [ $cgPDf -ne 0 ]; then
    if [ -f /etc/getBootstrapProperty.sh ]; then
        result=`/etc/getBootstrapProperty.sh $1`
        echo $result
        echo "[BP] Returning through getBootstrapProperty call for $1, result=$result" >> /opt/logs/rfcscript.log
    fi
fi

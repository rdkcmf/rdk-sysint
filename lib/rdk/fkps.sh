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
#
. /etc/include.properties
. /etc/device.properties

FKPS_BROKER_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Sysint.FkpsBrokerUrl 2>&1)
if [ -z "$FKPS_BROKER_URL" ]; then
    FKPS_BROKER_URL="https://fkpsbroker.ccp.xcal.tv"
fi

FKPS_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Sysint.FkpsUrl 2>&1)
if [ -z "$FKPS_URL" ]; then
    FKPS_URL="https://fkps.ccp.xcal.tv:443"
fi

getFKPSBURL()
{
    # assign default URL
    # known hosts:
    # PRODUCTION "fkpsbroker.ccp.xcal.tv"
    # STAGING "fkpsbroker-stage.ccp.xcal.tv"
    # QA "fkpsbroker-qa.ccp.xcal.tv"
    defaultURL="$FKPS_BROKER_URL"
    result=${defaultURL}

    # if configuration file exists and build type is not production
    # then read URL from configuration file
    if [ -f $PERSISTENT_PATH/fkpsb.conf ] && [ "$BUILD_TYPE" != "prod" ] ; then
        urlString=`grep -v '^[[:space:]]*#' $PERSISTENT_PATH/fkpsb.conf`
        if [ -n "$urlString" ] ; then
            result=${urlString}
        fi
    fi

    echo -n ${result}
}

getFKPSURL()
{
    # assign default URL
    defaultURL="$FKPS_URL"
    # get build type
    result=${defaultURL}

    # if configuration file exists and build type is not production
    # then read URL from configuration file
    if [ -f $PERSISTENT_PATH/fkps.conf ] && [ "$BUILD_TYPE" != "prod" ] ; then
        urlString=`grep -v '^[[:space:]]*#' $PERSISTENT_PATH/fkps.conf`
        if [ -n "$urlString" ] ; then
            result=${urlString}
        fi
    fi

    echo -n ${result}
}

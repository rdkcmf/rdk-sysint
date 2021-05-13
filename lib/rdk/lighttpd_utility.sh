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

# Defaults can be overridden in this file
INIT_SCRIPT_DEFAULTS_FILE="/etc/include.properties"

# Load alternate configuration if exists
if [ -f $INIT_SCRIPT_DEFAULTS_FILE ]; then
     . $INIT_SCRIPT_DEFAULTS_FILE
fi

. /etc/device.properties
. $RDK_PATH/utils.sh

LOGFILE=$LOG_PATH/lighttpd.log

mkdir -p /opt/www
cp -a /opt_back/* /opt/
rm -rf /opt/www/htmldiag

if [ -d /htmldiag2 ]; then
    rm -rf /opt/www/htmldiag2
fi

if [ -d /opt/www/xrehtml ]; then
    rm -rf /opt/www/xrehtml
fi
if [ -d /opt/www/xrehtml_yocto ]; then
    rm -rf /opt/www/xrehtml_yocto
fi

if [ "$WHITEBOX_ENABLED" == "true" ]; then
    . /etc/wbdevice.conf
    mkdir -p $wbpath

    lighttpd -m /usr/local/lib -f /etc/lighttpd.conf

    if [ ! -f /etc/wbdevice.conf ] || [ ! -f /etc/wbdevice ]; then
         echo "wbdevice service cannot start"
         exit 1
    else
         if [ ! -s $wbpath/wbmac.dat ] ; then
	     echo "creating $wbpath/wbmac.dat"
	         echo -n $(getEstbMacAddress) > $wbpath/wbmac.dat
         fi
         /usr/local/bin/spawn-fcgi -fcgi /etc/wbdevice -a 127.0.0.1 -p 9620 &
         # Dual activation steps for delia
         if [ "$DEVICE_TYPE" = "hybrid" ]; then
              if [ -f /opt/enable_delia_dual ] && [ "$BUILD_TYPE" != "prod" ]; then
	          . /etc/wbdevice2.conf
	          mkdir -p $wbpath
     	          ifconfig | grep 'eth1' | tr -s ' ' | cut -d ' ' -f5 | tr -d '\r\n' > $wbpath/wbmac.dat
	          WB_CONF_FILE=/etc/wbdevice2.conf WB_LOG_FILE=$LOG_PATH/wbdevice2.log spawn-fcgi -fcgi /etc/wbdevice -a 127.0.0.1 -p 9621 &
              fi
         fi

         if [ -x /etc/authservice.sh ]; then
	      /etc/authservice.sh start
         fi
    fi
else
    lighttpd -m /usr/local/lib -f /etc/lighttpd.conf
   
    if [ -x /etc/authservice.sh ]; then
         /etc/authservice.sh start
    fi
fi

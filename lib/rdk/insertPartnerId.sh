#! /bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2021 RDK Management, LLC. All rights reserved.
# ============================================================================
##################################################################
## This script inserts a random uuid as receiver id and partner id as community.
#
## Author: RDK Community
##################################################################

#Check whether time event is received
if [ -f /usr/bin/timedatectl ] ; then
   ntpstatus=`timedatectl |grep "Network time on"|cut -d ':' -f2 |xargs`

   if [ "$ntpstatus" = "yes" ] ; then
        touch /tmp/stt_received
   fi
fi

#Check whether authservice file already exists
response=`curl --write-out "%{http_code}\n" --silent --output /dev/null http://localhost:50050/authService/getDeviceId`
if [ $response -eq 200 ] ; then
   echo "All set. Exiting"
else
   uuid=`uuidgen`
   echo "{ \"deviceId\" : \"$uuid\" , \"partnerId\": \"community\" }" >~/authService/getDeviceId
fi

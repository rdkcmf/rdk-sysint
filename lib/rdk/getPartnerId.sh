#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2017 RDK Management, LLC. All rights reserved.
# ============================================================================
##################################################################
## Script to retrieve receiver ID and partner ID
#
## Author: Milorad Neskovic
##################################################################

if [ "$WHITEBOX_ENABLED" == "true" ]; then
    . /etc/wbdevice.conf
else
    wbpath=/opt/www/whitebox/
fi

. /etc/authService.conf

getReceiverId()
{
    outputR=`awk -F',' </tmp/gpid.txt '{ for (i=1; i<=NF; i++) print $i}'| grep deviceId | cut -d ":" -f2 | tr -d " " |sed -e 's/[{,},/"]//g'`
    deviceId=`echo "$outputR" | tr '[A-Z]' '[a-z]'`

    if [ "$deviceId" != "" ]; then
       echo "$deviceId"
    else
       if [ -f $aspath/deviceid.dat ]; then    
           cat $aspath/deviceid.dat
       elif [ -f $wbpath/wbdevice.dat ]; then
           cat $wbpath/wbdevice.dat
       else
           echo ""
       fi
    fi       
}
 
getPartnerId()
{
    # Check for the partner ID
    curl -d '' -X POST http://127.0.0.1:50050/authService/getDeviceId >/tmp/gpid.txt
    output=`awk -F',' </tmp/gpid.txt '{ for (i=1; i<=NF; i++) print $i}'| grep partnerId | cut -d ":" -f2 | tr -d " " |sed -e 's/[{,},/"]//g'`
    partnerName=`echo "$output" | tr '[A-Z]' '[a-z]'`
	
    if [ "$partnerName" != "" ]; then
       echo "$partnerName"
    else
        if [ -s $aspath/partnerId3.dat ]; then
            cat $aspath/partnerId3.dat
        else
            # receiverId and partnerId are retrieved as a set
            receiverId=$(getReceiverId)

            if [ "$receiverId" != "" ]; then
                echo "comcast"
            else
                echo ""
            fi
        fi
    fi
}

getExperience()
{
    # Check for the Experience
    curl -s -d '' -X POST http://127.0.0.1:50050/authService/getExperience >/tmp/gpid.txt
    experience=`awk -F',' </tmp/gpid.txt '{ for (i=1; i<=NF; i++) print $i}'| grep experience | cut -d ":" -f2 | tr -d " " |sed -e 's/[{,},/"]//g'`

    if [ "$experience" != "" ]; then
       echo "$experience"
    else
        echo "X1"
    fi
}

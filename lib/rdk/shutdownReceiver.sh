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

sleepTime=10

originalReceiverPid=`pidof Receiver`

kill $originalReceiverPid

echo "sleeping for " . $sleepTime " seconds before checking if receiver restart was successful"
sleep $sleepTime 
echo "checking to see if the receiver restart was successful"


newReceiverPid=`pidof Receiver`

if [ "$originalReceiverPid" == "$newReceiverPid" ]
then
  echo "killing the receiver with -9"
  kill -9 $originalReceiverPid
else
  echo "receiver restart was successful on first try"
fi

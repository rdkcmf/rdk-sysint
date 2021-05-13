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

mount | grep sda2 | grep rtdev
if [ $? -ne 0 ]; then
  echo "Its not a realtime XFS partition..."
  opt=`ps | grep opt | cut -d ' ' -f2`
  killall -9 lighttpd
  kill -9 $opt
  umount /dev/sda1
  umount /dev/sda2
  echo "Creating realtime XFS filesystem"
  mkfs.xfs -f -b size=4096 -d agcount=4 -s size=4096 -l size=2m -r extsize=4m,rtdev=/dev/sda1 /dev/sda2
  sleep 10
  sync
  echo "realtime XFS created.. rebooting box now"
  sh /rebootNow.sh -s XFS -o "Rebooting the box after realtime XFS creation..."
else
  fsck.xfs /dev/sda1
  fsck.xfs /dev/sda2
fi

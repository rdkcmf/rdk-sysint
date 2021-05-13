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

cleanup()
{
   path=$1
   size=$2
   optSize=`du -k $path | awk '{print $1}'| sed 's/[^0-9]*//g'`

   if [ $optSize -gt $size ]; then
         while [ $optSize -gt $size ]
         do
             oldFile=`ls -t $path | tail -1`
             echo $oldFile
             if [ -f $path/$oldFile ]; then rm -rf $path/$oldFile; fi
                  optSize=`du -k $path | awk '{print $1}'| sed 's/[^0-9]*//g'`
             sleep 1
         done
  fi
}

# cleaning coredump backup area
cleanup /opt/corefiles_back/ 2097152
cleanup /opt/secure/corefiles_back/ 2097152
# cleaning coredump area
cleanup /opt/corefiles/ 2097152
cleanup /var/lib/systemd/coredump/ 2097152
cleanup /opt/secure/corefiles/ 2097152
# cleaning minidump area
cleanup /opt/minidumps/ 512000
cleanup /opt/secure/minidumps/ 512000
exit 0

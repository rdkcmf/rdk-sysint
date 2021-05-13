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
#
#########################################################################
## Script to get LSA Params from RFC and return the enable/disable value
#########################################################################

. /etc/include.properties

readLSAParamFromRFC()
{
   _flagEnabled=0
   result_getRFC=77

   if [ -f /lib/rdk/getRFC.sh ]; then
      . $RDK_PATH/getRFC.sh LSA

      case $1 in
         AD_CACHE)
            if [ ! -z "$RFC_DATA_LSA_AdCacheEnable" ]; then
               _flagEnabled=$(echo $RFC_DATA_LSA_AdCacheEnable)
            fi
         ;;

         PROGRAMMER_ENABLEMENT)
            if [ ! -z "$RFC_DATA_LSA_ProgrammerEnablement" ]; then
               _flagEnabled=$(echo $RFC_DATA_LSA_ProgrammerEnablement)
            fi
         ;;

         BYTE_RANGE_DOWNLOAD)
            if [ ! -z "$RFC_DATA_LSA_ByteRangeDownload" ]; then
               _flagEnabled=$(echo $RFC_DATA_LSA_ByteRangeDownload)
            fi
         ;;

      esac
   fi
   echo $_flagEnabled
}

if [ $# -eq 1 ]; then
   readLSAParamFromRFC $1
   returniF=$?
else
   returniF=-1
fi

#!/bin/sh
##############################################################################
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2020 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##############################################################################

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

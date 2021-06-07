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

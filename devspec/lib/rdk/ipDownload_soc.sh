#!/bin/sh
##########################################################################
# If not stated otherwise in this file or this component's LICENSE
# file the following copyright and licenses apply:
#
# Copyright 2018 RDK Management
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
##########################################################################

deviceCleanup()
{
   WORK_PATH=`pwd`
   cd /
   rm -rf startParker lib/libPace*
   cd $WORK_PATH
}

flashTheKernel()
{
   export LD_LIBRARY_PATH=/lib:/usr/local/lib:/usr/local/qt/lib:/mnt/nfs/bin/usr/lib
   usr/sbin/fwtest -c "console=ttyS0,115200 rw memmap=exactmap memmap=64K@0 memmap=160K@96K  memmap=575M@1M vmalloc=768M rootwait panic=5 root=/dev/sda3  nmi_watchdog=1"
}

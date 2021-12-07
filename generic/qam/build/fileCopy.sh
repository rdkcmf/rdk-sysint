#!/bin/bash
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

set -x
echo $FSROOT
echo $COMBINED_ROOT

startupDir=$FSROOT/lib/rdk

cp $startupDir/rebootNow.sh $FSROOT/
cp $startupDir/rebootSTB.sh $FSROOT/
cp $startupDir/savepwrstate.sh $FSROOT/
#cp $startupDir/updateSysTime.sh $FSROOT/

# Clean up copy of files from sysint folder
rm $startupDir/rebootNow.sh 
rm $startupDir/rebootSTB.sh 
rm $startupDir/savepwrstate.sh
#rm $startupDir/updateSysTime.sh

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

#
#    echo "Usage: $0 <File Path> "

. /etc/include.properties
. /etc/device.properties

# Set the log rotate property file
propertyFile="/etc/logRotate.properties"
if [ "$BUILD_TYPE" != "prod" ]; then
      if [ -f $PERSISTENT_PATH/logRotate.properties ]; then
            propertyFile="$PERSISTENT_PATH/logRotate.properties"
      fi
fi

. $propertyFile

# Assign the file path
FILE_PATH=$1

# File and directory name
DIR_PATH=`dirname $FILE_PATH`
FILE=`basename $FILE_PATH`

# current log rotate threshold value
count=$logRotateCount

# Move to the log rotate folder
cd $DIR_PATH

i=1
while [ $i -le $count ]
do
    segment=${FILE}.${i}
    if [ -f $segment ]
    then
        echo "renaming $segment"
        name1=`echo $segment |cut -d '.' -f1`
        name2=`echo $segment |cut -d '.' -f2`
        name3=`echo $segment |cut -d '.' -f3`
        mv $segment ${name1}_${name3}.${name2}
    fi
    i=`expr $i + 1`
done

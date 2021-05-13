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

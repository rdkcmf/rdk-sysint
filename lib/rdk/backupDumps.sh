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


. /etc/device.properties
if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
. /lib/rdk/getSecureDumpStatus.sh
fi

getCoredumpName()
{
    echo `ls core.prog_$APPLICATION_NAME*`
}
getMinidumpName()
{
    for file in `ls $MINIDUMPS 2> /dev/null`
    do
	if [ `expr length $file` -le $MINIDUMP_GUID_LENGTH  ]; then
            echo $file
	    return
	fi
    done
}

if [ $# -eq 1 ]; then
     APPLICATION_NAME=$1
else
     APPLICATION_NAME="unknown"
fi

export $APPLICATION_NAME
export COREFILES_DIR=$CORE_PATH
export COREFILES_BACKUP_DIR=$CORE_BACK_PATH
export MINIDUMPS_DIR=$MINIDUMPS_PATH
export MINIDUMPS=*.dmp
export MINIDUMP_GUID_LENGTH=40

cd $COREFILES_DIR
export coredump_name=`getCoredumpName`
cd $MINIDUMPS_DIR
export minidump_name=`getMinidumpName`
export new_coredump_name=$minidump_name"_"`echo $coredump_name | tr _ '-'`
export new_minidump_name=`echo $coredump_name | tr _ '-'`"_"$minidump_name

if [ $coredump_name ] && [ $minidump_name ]; then 
	mv $COREFILES_DIR/$coredump_name $MINIDUMPS_DIR/$new_coredump_name
	mv $MINIDUMPS_DIR/$minidump_name $MINIDUMPS_DIR/$new_minidump_name
elif [ $coredump_name  ] ; then
	mkdir -p $COREFILES_BACKUP_DIR
	mv $COREFILES_DIR/$coredump_name $COREFILES_BACKUP_DIR 
fi

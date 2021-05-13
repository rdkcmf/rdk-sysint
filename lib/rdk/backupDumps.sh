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

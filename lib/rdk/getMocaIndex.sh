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

MAX_RETRY_COUNT=25
count=0

export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
export MIBS=ALL
export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
export PATH=$PATH:$SNMP_BIN_DIR:
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib

while [ ${count} -le ${MAX_RETRY_COUNT} ]
do
        index=`snmpwalk -m IF-MIB -v 2c -c private localhost 1.3.6.1.2.1.2.2  | grep 236 | cut -d '=' -f1 | cut -d '.' -f2`
        if [[ -z "$index" ]]; then
                sleep 2
        else
                echo $index > /tmp/.mocaIndex.txt
                exit 0
        fi
        count=$((count+1))
done

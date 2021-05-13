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

cd /mnt/nfs/env

#set environment
export SNMPCONFPATH=/mnt/nfs/bin/target-snmp/sbin
export MIBS=ALL
export MIBDIRS=/mnt/nfs/bin/target-snmp/share/snmp/mibs
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
export PATH=$PATH:/mnt/nfs/bin/target-snmp/bin

#start snmp daemon
sh ../bin/target-snmp/sbin/restart_snmpd.sh &

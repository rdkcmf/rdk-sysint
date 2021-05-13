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
# this script uses vmstat to print out following information
# vmInfoHeader: swpd,free,buff,cache,si,so
# vmInfoValues: <int>,<int>,<int>,<int>,<int>,<int>

vmstat > /tmp/.intermediate_calc_vm
echo "VM STATS SINCE BOOT"
values1=`sed '2q;d' /tmp/.intermediate_calc_vm| awk '{print $3","$4","$5","$6","$7","$8}'`
values2=`sed '3q;d' /tmp/.intermediate_calc_vm| awk '{print $3","$4","$5","$6","$7","$8}'`
echo vmInfoHeader: $values1
echo vmInfoValues: $values2

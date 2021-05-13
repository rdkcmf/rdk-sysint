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

iostat -c 1 2 > /tmp/.intermediate_calc
sed -i '/^$/d' /tmp/.intermediate_calc
echo "INSTANTANEOUS CPU INFORMATIONS"
values1=`sed '4q;d' /tmp/.intermediate_calc| tr -s " " | cut -c10-| tr ' ' ','`
values2=`sed '5q;d' /tmp/.intermediate_calc| tr -s " " | cut -c2-| tr ' ' ','`
echo cpuInfoHeader: $values1
echo cpuInfoValues: $values2
free | awk '/Mem/{printf("USED_MEM:%d\nFREE_MEM:%d\n"),$3,$4}'


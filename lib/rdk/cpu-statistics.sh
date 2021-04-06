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

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi


iostat -c 1 2 > /tmp/.intermediate_calc
sed -i '/^$/d' /tmp/.intermediate_calc
echo "INSTANTANEOUS CPU INFORMATIONS"
values1=`sed '4q;d' /tmp/.intermediate_calc| tr -s " " | cut -c10-| tr ' ' ','`
values2=`sed '5q;d' /tmp/.intermediate_calc| tr -s " " | cut -c2-| tr ' ' ','`
echo cpuInfoHeader: $values1
echo cpuInfoValues: $values2
t2ValNotify "cpuinfo_split" "$values2"
free | awk '/Mem/{printf("USED_MEM:%d\nFREE_MEM:%d\n"),$3,$4}'
mem=`free | awk '/Mem/{printf $4}'`
t2ValNotify "FREE_MEM_split" "$mem"

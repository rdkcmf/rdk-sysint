#!/bin/sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2021 RDK Management, LLC. All rights reserved.
# ============================================================================

# Added to create dummy nodes for msync (AMLOGIC-1677)
mknod -m 660 /dev/avsync_s0 c 280 0
mknod -m 660 /dev/avsync_s1 c 280 1
mknod -m 660 /dev/avsync_s2 c 280 2
mknod -m 660 /dev/avsync_s3 c 280 3
mknod -m 660 /dev/avsync_s4 c 280 4
mknod -m 660 /dev/avsync_s5 c 280 5
mknod -m 660 /dev/avsync_s6 c 280 6
mknod -m 660 /dev/avsync_s7 c 280 7
mknod -m 660 /dev/avsync_s8 c 280 8
chown 0:vpu /dev/avsync_s*
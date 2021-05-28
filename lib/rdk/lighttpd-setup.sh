#!/bin/busybox sh
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2016 RDK Management, LLC. All rights reserved.
# ============================================================================

if [ ! -d /opt/www ];then
    mkdir -p /opt/www
else
    rm -rf /opt/www/htmldiag
    rm -rf /opt/www/htmldiag2
    rm -rf /opt/www/hwselftest
    rm -rf /opt/www/pxDiagnostics
fi

if [ -d /home/root/pxDiagnostics ];then
    rm -rf /opt/www/pxDiagnostics
    ln -sf /home/root/pxDiagnostics /opt/www/pxDiagnostics
fi

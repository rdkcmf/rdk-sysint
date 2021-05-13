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

if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
     . /lib/rdk/getSecureDumpStatus.sh
fi

umount -f /opt/restricted/bin
umount -f /opt/restricted/sysint
umount -l /opt/restricted/tmp
umount -f /opt/restricted/opt/logs
sleep 1
umount -f /opt/restricted/opt/.adobe
umount -f /opt/restricted/opt/.macromedia
umount -f /opt/restricted/opt/xupnp/
umount -f /opt/restricted/opt/QT
sleep 1
umount -f /opt/restricted$CORE_PATH
umount -f /opt/restricted$CORE_BACK_PATH
umount -f /opt/restricted$MINIDUMPS_PATH
umount -f /opt/restricted/opt
umount -f /opt/restricted/lib/rdk
umount -f /opt/restricted/lib
sleep 1
umount -f /opt/restricted/mnt/nfs/bin
umount -f /opt/restricted/mnt/nfs/env
umount -l /opt/restricted/proc
umount -l /opt/restricted/sys
umount -l /opt/restricted/dev/shm
umount -l /opt/restricted/dev
sleep 1
umount -f /opt/restricted/sbin                         
umount -f /opt/restricted/var/logs                     
umount -f /opt/restricted/usr/local/lib                
umount -f /opt/restricted/usr/local/Qt                     
umount -f /opt/restricted/usr/local/bin   
sleep 1                       
umount -f /opt/restricted/usr/lib                          
umount -f /opt/restricted/usr/bin
umount -f /opt/restricted/usr
umount -f /opt/restricted/.ssh
umount -f /opt/restricted/etc/.ssh
umount -f /opt/restricted/etc                              
sleep 1

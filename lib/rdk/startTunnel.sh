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

. /etc/include.properties
. /etc/device.properties

usage()
{
  echo "USAGE:   startTunnel.sh {start|stop} {args}"
}

if [ $# -lt 1 ]; then
   usage
   exit 1
fi

oper=$1
shift

case $oper in 
           h)
             usage
             exit 1
             ;;
           start)
             if [ ! -f /usr/bin/GetConfigFile ];then
                 echo "Error: GetConfigFile Not Found"
                 exit 127
             fi
             GetConfigFile /tmp/nvgeajacl.ipe
             /usr/bin/ssh -i /tmp/nvgeajacl.ipe $*
             rm /tmp/nvgeajacl.ipe
             exit 1
             ;;
           stop)
             cat /var/tmp/rssh.pid |xargs kill -9
             rm /var/tmp/rssh.pid
             exit 1
             ;;
           *)
             usage
             exit 1
esac

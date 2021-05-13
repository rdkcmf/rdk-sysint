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
proxyPath=`cat /mnt/nfs/env/final.properties | grep OCAP.persistent.root | cut -d "=" -f2`
echo --------- proxy path= $proxyPath
     #rm $proxyPath/usr/1112/703e/proxy-is-up
     #rm /tmp/stt_received

while [ 1 ]
  do
        if [ -f $proxyPath/usr/1112/703e/proxy-is-up ] ; then
	          echo "Proxy is UP"
	          if [ -f /opt/gzenabled ]; then
		      val=`cat /opt/gzenabled`
		      if [ $val -eq 1 ] ; then
			echo -e 't2p:msg\n{setGroundZeroProperties:{"gzEnabled": true}}\nt2p:msg' | nc localhost 3773
			exit 0
		      else
			exit 0
		      fi
		  else
		    exit 0
		  fi
        else
           sleep 5
        fi
  done

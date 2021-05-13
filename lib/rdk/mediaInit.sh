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
if [ -f /opt/gzenabled ]; then
      val=`cat /opt/gzenabled`
         if [ $val -eq 1 ] ; then
            echo "starting Receiver soon GLI requirement"
            while [ 1 ]
	    do
	      if [ -f /tmp/mediaReady ] ; then
	          echo "MPEOS media is UP"
	          exit 0
	      else
		  echo "[GZ is enabled]"
		  sleep 1
	      fi
	    done
         else
            echo "[GZ is not enabled]don't have to wait!!"
         fi
else
     echo "[GZ is not enabled]!!" 
fi



#!/bin/sh
##############################################################################
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2020 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##############################################################################

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

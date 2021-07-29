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


export TERM=xterm
export HOME=/home/root
. /etc/include.properties
. /etc/device.properties

usage()
{
  echo "USAGE:  startSTunnel.sh <localport> <jumpserverip> <jumpserverport>"
}

if [ $# -lt 3 ]; then
   usage
   exit 1
fi

LOG_FILE="$LOG_PATH/stunnel.log"

#prepare things
K_DIR="/tmp/eaqafxwah"
S_FILE="/etc/ssl/certs/eaqafxwah.vmk"
D_FILE="/tmp/eaqafxwah/eaqafxwah.vmk"
mkdir -p /tmp/eaqafxwah
configparamgen jx $S_FILE $D_FILE

#collect the arguments
#    1) CPE's available port starting from 3000
#    2) FQDN of jump server
#    3) Port number of stunnel's server instance at jump server
LOCAL_PORT=$1
JUMP_SERVER=$2
JUMP_PORT=$3

STUNNEL_PID_FILE=/tmp/stunnel.pid
STUNNEL_CONF_FILE=/tmp/stunnel_$LOCAL_PORT.conf

echo  "pid = $STUNNEL_PID_FILE"           > $STUNNEL_CONF_FILE
echo  "output=$LOG_FILE"                 >> $STUNNEL_CONF_FILE
echo  "debug = 7"                        >> $STUNNEL_CONF_FILE
echo  "[ssh]"                            >> $STUNNEL_CONF_FILE
echo  "client = yes"                     >> $STUNNEL_CONF_FILE

# Use localhost to listen on both IPv4 and IPv6
echo "accept = localhost:$LOCAL_PORT"     >> $STUNNEL_CONF_FILE
echo "connect = $JUMP_SERVER:$JUMP_PORT" >> $STUNNEL_CONF_FILE

# this might change once we get proper certificates
echo "key = $D_FILE"                                                  >> $STUNNEL_CONF_FILE
echo "cert = /etc/ssl/certs/device_tls_cert.pem"                      >> $STUNNEL_CONF_FILE
echo "CAfile =/etc/ssl/certs/comcast-rdk-revshell-server-ca.cert.pem" >> $STUNNEL_CONF_FILE
echo "verifyChain = yes"                                              >> $STUNNEL_CONF_FILE
echo "checkHost = $JUMP_SERVER"                                       >> $STUNNEL_CONF_FILE 

/usr/bin/stunnel $STUNNEL_CONF_FILE

# cleanup sensitive files early
rm -f $STUNNEL_CONF_FILE
rm -f $D_FILE

# stunnel client instance will be killed by watchTunnel.sh, when the associated
# sesssion of SSH tunnel is closed or timed-out.


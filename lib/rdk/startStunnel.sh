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

usage()
{
  echo "USAGE:  startSTunnel.sh <ip_ver> <localip> <jumpserverip> <jumpserverport> <remoteTerminalRows> <remoteTerminalColumns>"
}

if [ $# -lt 6 ]; then
   usage
   exit 1
fi

#prepare things
K_DIR="/tmp/eaqafxwah"
S_FILE="/etc/ssl/certs/eaqafxwah.vmk"
D_FILE="/tmp/eaqafxwah/eaqafxwah.vmk"
mkdir -p /tmp/eaqafxwah
configparamgen jx $S_FILE $D_FILE

#collect the arguments
IP_VER=$1
LOCAL_IP=$2
JUMP_SERVER=$3
JUMP_PORT=$4
ROWS=$5
COLUMNS=$6

#echo "got command $IP_VER $LOCAL_IP $JUMP_SERVER $JUMP_PORT $ROWS $COLUMNS" > /tmp/webpa_command

# there is no harm in using the same port as jump server as 
# interfaces are different and it was gnerated randmol anyway

STUNNEL_PID_FILE=/tmp/stunnel_pid_$JUMP_PORT.pid
STUNNEL_CONF_FILE=/tmp/stunnel_$JUMP_PORT.conf

echo  "pid = $STUNNEL_PID_FILE"           > $STUNNEL_CONF_FILE
#echo "output=/tmp/cpe_tunnelssh.log"    >> $STUNNEL_CONF_FILE
#echo "debug = 7"                        >> $STUNNEL_CONF_FILE
echo  "[ssh]"                            >> $STUNNEL_CONF_FILE
echo  "client = yes"                     >> $STUNNEL_CONF_FILE

# keep the arguments in ip ver format for clarity 
# just ipv6 might work as in most cases a bind to ipv6 includes ipv4 for most cases
if [ $IP_VER -eq 4 ] 
then
    echo "accept = 127.0.0.1:$JUMP_PORT"     >> $STUNNEL_CONF_FILE
    echo "connect = $JUMP_SERVER:$JUMP_PORT" >> $STUNNEL_CONF_FILE
else
    echo "accept = ::1:$JUMP_PORT"           >> $STUNNEL_CONF_FILE
    echo "connect = $JUMP_SERVER:$JUMP_PORT" >> $STUNNEL_CONF_FILE
fi


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

if [ $IP_VER -eq 4 ] 
then
    /usr/bin/socat -w rows=$ROWS columns=$COLUMNS exec:'bash -li',pty,stderr,setsid,sigint,sane tcp:127.0.0.1:$JUMP_PORT
else
    /usr/bin/socat -w rows=$ROWS columns=$COLUMNS exec:'bash -li',pty,stderr,setsid,sigint,sane tcp6:[::1]:$JUMP_PORT
fi

stunnel_pid=`cat $STUNNEL_PID_FILE`
kill $stunnel_pid


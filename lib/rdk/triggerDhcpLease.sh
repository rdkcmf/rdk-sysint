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


if [ "$1" == "renew" ]; then
    if [ "$2" == "" ]; then
        pidfiles=$(ls /tmp/udhcpc.*.pid 2> /dev/null)
    else
        pidfiles=$(ls /tmp/udhcpc.${2}{,:[0-9]*}.pid 2> /dev/null)
    fi
    if [ "$pidfiles" == "" ]; then
        echo "error: no udhcpc PID files found"
        exit 1
    fi
    for pidfile in $pidfiles; do
        echo "/bin/kill -SIGUSR1 $(cat $pidfile) ($pidfile)"
        /bin/kill -SIGUSR1 $(cat $pidfile)
    done
elif [ "$1" == "release_and_renew" ]; then
    if [ "$2" == "" ]; then
        echo "error: argument 2 must specify interface (wlan0, eth0, etc.) if argument 1 is release_and_renew"
        exit 1
    else
        pidfiles=$(ls /tmp/udhcpc.${2}{,:[0-9]*}.pid 2> /dev/null)
    fi
    if [ "$pidfiles" == "" ]; then
        echo "error: no udhcpc PID file found"
        exit 1
    fi
    for pidfile in $pidfiles; do
        echo "/bin/kill -SIGUSR2 $(cat $pidfile) ($pidfile)"
        /bin/kill -SIGUSR2 $(cat $pidfile)
        echo "/bin/kill -SIGUSR1 $(cat $pidfile) ($pidfile)"
        /bin/kill -SIGUSR1 $(cat $pidfile)
    done
else
    echo "error: argument 1 must be 'renew' or 'release_and_renew'"
    exit 1
fi

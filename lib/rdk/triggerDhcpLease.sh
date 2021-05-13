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

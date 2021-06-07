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


. /etc/device.properties

PREVIOUS_PINGTEST_COUNT="/opt/previous_pingtest_count"
PINGDATA_FILE="/opt/pingtest_data"
PING_TELEMETRY_LOGFILE="/opt/logs/ping_telemetry.log"

# Getting the previous burst count, so that we calculate only the latest pingdata
previous_pingtest_count=0
if [ -f $PREVIOUS_PINGTEST_COUNT ] && [ "`cat $PREVIOUS_PINGTEST_COUNT`" != "" ]; then
    previous_pingtest_count=`cat $PREVIOUS_PINGTEST_COUNT`
fi

# Exiting if ping data file is not available
if [ ! -f $PINGDATA_FILE ]; then
    echo "`timestamp` PingData:Ping test not started yet, ping data file missing"
    exit 0
fi

# Getting the total burst count
current_pingtest_count=`cat $PINGDATA_FILE | grep "packet loss" | wc -l`

# Function to get network interface
get_network_interface_name () {
    if [ "$DEVICE_TYPE" == "mediaclient" ]; then
        ping_interface="MoCA"
        if [ "$MOCA_SUPPORT" == "false" ]; then
            ping_interface="Ethernet"
        fi    
        if [ -f /tmp/wifi-on ]; then
            ping_interface="WiFi"
        fi
    else
        ping_interface="eSTB"
    fi
    echo "$ping_interface"
}

# Function to calculate the packet transmitted, received and loss during last window
get_ping_packetdata () {
    # Skip the rtt info if packet loss is 100%. For 100% packet loss, ping wont output rtt min/max/avg 
    skip_rtt_info=0
    
    value=`cat $PINGDATA_FILE | grep "packet loss" | tail -n $1 | sed "s/loss/loss;/g"`
    count=0
    while [ $count -ne $1 ]
    do
        count=`expr $count + 1`
        line=`echo $value | cut -d ';' -f$count | sed 's/^[ \t]*//;s/, /,/g'`
    
        packets_tx=`awk "BEGIN {print $packets_tx+ $(echo $line | cut -d ',' -f1 | cut -d ' ' -f1); exit}"`
        packets_rcvd=`awk "BEGIN {print $packets_rcvd+ $(echo $line | cut -d ',' -f2 | cut -d ' ' -f1); exit}"`
        current_loss=`echo $line | cut -d ',' -f3 | cut -d '%' -f1`
        packet_loss=`awk "BEGIN {print $packet_loss+ $current_loss; exit}"`
        if [ $current_loss -eq 100 ]; then
            skip_rtt_info=`expr $skip_rtt_info + 1`
        fi
    done
    packet_loss=`awk "BEGIN {print $packet_loss / $1; exit}"`
    echo "`timestamp` PingData:packet-info tx/rcvd/loss:$packets_tx,$packets_rcvd,$packet_loss"    
    return $skip_rtt_info
}

# Function to calculate rtt min, avg, max and mdev during last window
get_ping_rttdata () {
    valid_rtt_count=$1
    value=`cat $PINGDATA_FILE | grep "round-trip" | tail -n $valid_rtt_count`
    count=0
    while [ $count -ne $valid_rtt_count ]
    do
        count=`expr $count + 1`
        splitter=`expr $count + 1`
        line=`echo $value | cut -d "=" -f$splitter | cut -d ' ' -f2`
        
        rtt_min=`awk "BEGIN {print $rtt_min+ $(echo $line | cut -d "/" -f1); exit}"`
        rtt_avg=`awk "BEGIN {print $rtt_avg+ $(echo $line | cut -d "/" -f2); exit}"`
        rtt_max=`awk "BEGIN {print $rtt_max+ $(echo $line | cut -d "/" -f3); exit}"`
        rtt_mdev=`awk "BEGIN {print $rtt_mdev+ $(echo $line | cut -d "/" -f4); exit}"`
    done
    
    rtt_min=`awk "BEGIN {print $rtt_min / $1; exit}"`
    rtt_avg=`awk "BEGIN {print $rtt_avg / $1; exit}"`
    rtt_max=`awk "BEGIN {print $rtt_max / $1; exit}"`
    rtt_mdev=`awk "BEGIN {print $rtt_mdev / $1; exit}"`
    
    echo "`timestamp` PingData:rtt min/avg/max/mdev:$rtt_min,$rtt_avg,$rtt_max,$rtt_mdev"
}        

# Function to calculate the total time taken for the ping in last window
get_pingtime () {
    value=`cat $PINGDATA_FILE | grep ping_time | tail -n $1 | cut -d ':' -f2`
    time=`echo $value | cut -d ' ' -f1`
    count=1
    while [ "$time" != "" ]
    do
        pingtime=`expr $pingtime + $time`
        if [ $1 -ne 1 ]; then
            count=`expr $count + 1`
            time=`echo $value | cut -d ' ' -f$count`
        else
            time=""
        fi    
    done
    echo "`timestamp` PingData:pingtime:$pingtime"
}
    
# Function to calculate pingdata for last telemetry window
get_telemetry_window_data () {

    # Initialising the variables
    packets_tx=0
    packets_rcvd=0
    packet_loss=0
    rtt_min=0
    rtt_avg=0
    rtt_max=0
    rtt_mdev=0
    pingtime=0
    
    get_ping_packetdata $1
    skip_rtt_info=$?
    
    # Calculating the rtt min, avg, max, mdev during last window
    if [ $1 -gt $skip_rtt_info ]; then
        valid_rtt_count=`expr $1 - $skip_rtt_info`
        get_ping_rttdata $valid_rtt_count
    fi    
    
    get_pingtime $1
    
    # getting the ping test type and packet size for sending in telemetry data
    ping_test_type=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.PingTelemetry.Type 2>&1 > /dev/null`
    [ "$ping_test_type" == "" ] && ping_test_type="ICMP"
    ping_packet_size=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.PingTelemetry.DataBlockSize 2>&1 > /dev/null`
    [ ! $ping_packet_size ] || [ $ping_packet_size -le 0 ] && ping_packet_size=1500

    ping_interface=$(get_network_interface_name)

    #Formulating Json pingdata
    ping_telemetry_data=`echo {\"pingData\":[{\"pingTestType\":\"$ping_test_type\",\"blockSize\":\"$ping_packet_size\",\"networkInterface\":\"$ping_interface\", \
        \"packets_tx\":\"$packets_tx\",\"packets_rcvd\":\"$packets_rcvd\",\"packet_loss\":\"$packet_loss%\",\"time\":\"$pingtime\", \
        \"rtt_min\":\"$rtt_min\",\"rtt_avg\":\"$rtt_avg\",\"rtt_max\":\"$rtt_max\",\"rtt_mdev\":\"$rtt_mdev\"}]}`
        
    echo "`timestamp` PingData:ping telemetry data:$ping_telemetry_data"
    echo $ping_telemetry_data > /opt/pingData
}

# Checking for any new ping test. If yes, then calculating the data and output the jsondata
echo "`timestamp` PingData:pingcount current/previous:$current_pingtest_count,$previous_pingtest_count"
if [ $current_pingtest_count -gt $previous_pingtest_count ]; then
    # Storing the new burst count
    echo $current_pingtest_count > $PREVIOUS_PINGTEST_COUNT
    
    # calculating the burst count and pingdata for last telemetry window
    pingtest_telemetry_window_count=`expr $current_pingtest_count - $previous_pingtest_count`
    get_telemetry_window_data $pingtest_telemetry_window_count    
else
    echo "`timestamp` PingData:No test results for last telemetry window"
fi

# Doing cleanup if ping test is completed
if [ -f /tmp/pingtelemetry.pid ] && [ -d /proc/`cat /tmp/pingtelemetry.pid` ]; then
    echo "`timestamp` PingData:Ping Test is currently on-going, exiting without clean-up"
else
    echo "`timestamp` PingData:Ping Test completed and the data is sent as part of telemetry, Clearing the pingtest data"
    if [ -f $PINGDATA_FILE ]; then
        cat $PINGDATA_FILE >> $PING_TELEMETRY_LOGFILE  
        rm -rf $PINGDATA_FILE
        rm -rf $PREVIOUS_PINGTEST_COUNT
    fi    
fi

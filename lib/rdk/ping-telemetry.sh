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

. /etc/device.properties

if [ ! -f /etc/os-release ]; then
    IARM_EVENT_BINARY_LOCATION=/usr/local/bin
fi

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

# Setting ping interval as 1s (default interval of ping)
ping_interval=0.1

test_starttime=0
PINGDATA_FILE="/opt/pingtest_data"

# Selecting ping command based on IPv4/IPv6
ping_command="ping"
[ -f /tmp/estb_ipv6 ] && ping_command="ping6"

# Function to terminate test
skip_test () {
    echo "`timestamp` PingTelemetry:$1"
    exit 0
}    

# Waiting if device is in standby mode
while [ "$LIGHTSLEEP_ENABLE" == "true" ] && [ -f /tmp/.standby ]; 
do
    sleep 120
done
    
# Waiting till previous day ping test is in progress    
# This is to address corner cases 
while [ -f /tmp/pingtelemetry.pid ] && [ -d /proc/`cat /tmp/pingtelemetry.pid` ]
do
    echo "`timestamp` PingTelemetry:Previous Ping Telemetry is in progress"
    echo "`timestamp` PingTelemetry:Waiting for already running Ping Telemetry Test to complete"
    sleep 60
done
echo $$ > /tmp/pingtelemetry.pid

echo "`timestamp` ******* PingTelemetry:Start of Configurations *******" 
# get the RFC parameters and validate it. If empty, then use the default values
# Continue PingTest only if pingTestEnable is true
pingTestEnable=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.PingTelemetry.Enable 2>&1 > /dev/null`
echo "`timestamp` PingTelemetry:Ping telemetry enabled:$pingTestEnable"
if [ "$pingTestEnable" != "true" ]; then
    if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
    then
        eventSender "MaintenanceMGR" $MAINT_PINGTELEMETRY_ERROR
    fi
    skip_test "Exiting as ping telemetry is disabled"
fi
t2CountNotify "INFO_ICMP_RFC" 

# Getting the PingTelemetry start time, default value is 180
pingtelemetry_starttime=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.PingTelemetry.StartTime 2>&1 > /dev/null`
[ ! $pingtelemetry_starttime ] && pingtelemetry_starttime=180
[ $pingtelemetry_starttime -lt 0 ] && pingtelemetry_starttime=0

# Getting the PingTelemetry end time, default value is 1439
pingtelemetry_endtime=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.PingTelemetry.EndTime 2>&1 > /dev/null`
[ ! $pingtelemetry_endtime ] || [ $pingtelemetry_endtime -gt 1439 ] && pingtelemetry_endtime=1439
[ $pingtelemetry_endtime -lt $pingtelemetry_starttime ] && pingtelemetry_endtime=`expr $pingtelemetry_starttime + 1`

# converting into seconds
pingtelemetry_starttime=`expr $pingtelemetry_starttime \* 60`
pingtelemetry_endtime=`expr $pingtelemetry_endtime \* 60`
echo "`timestamp` PingTelemetry:pingtelemetry_starttime:$pingtelemetry_starttime(in sec)"
echo "`timestamp` PingTelemetry:pingtelemetry_endtime:$pingtelemetry_endtime(in sec)"

# Getting the ping destination, default value is "edge.ip-eas-dns.xcr.comcast.net"
ping_destination=`tr181Set Device.IP.Diagnostics.IPPing.Host  2>&1 > /dev/null`
echo "$ping_destination" | grep -v "comcast.net" && ping_destination=`cat /opt/previous_ping_destination`
[ "$ping_destination" == "" ] && ping_destination="edge.ip-eas-dns.xcr.comcast.net"
echo "$ping_destination" > /opt/previous_ping_destination    
echo "`timestamp` PingTelemetry:ping_destination:$ping_destination"

# Getting the ping test type, currently only ICMP is supported
ping_test_type=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.PingTelemetry.Type 2>&1 > /dev/null`
[ "$ping_test_type" == "" ] && ping_test_type="ICMP"
echo "`timestamp` PingTelemetry:ping_test_type:$ping_test_type"
if [ "$ping_test_type" != "ICMP" ]; then
    skip_test "Exiting as ping test type ($ping_test_type) is not supported, only ICMP is supported"
fi

# Getting the count of ping tests in a day, default is 10
burst_count=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.PingTelemetry.BurstCnt 2>&1 > /dev/null`
[ ! $burst_count ] || [ $burst_count -le 0 ] && burst_count=10
echo "`timestamp` PingTelemetry:burst_count:$burst_count"

# Getting the packet count sent in a single ping test, default is 1000
packet_count=`tr181Set Device.IP.Diagnostics.IPPing.NumberOfRepetitions 2>&1 > /dev/null`
[ ! $packet_count ] || [ $packet_count -le 0 ] && packet_count=1000
echo "`timestamp` PingTelemetry:packet_count:$packet_count"

# Getting the ping packet size, default is 1500
ping_packet_size=`tr181Set Device.IP.Diagnostics.IPPing.DataBlockSize 2>&1 > /dev/null`
[ ! $ping_packet_size ] || [ $ping_packet_size -le 0 ] && ping_packet_size=1500
echo "`timestamp` PingTelemetry:ping_packet_size:$ping_packet_size"

echo "`timestamp` ******* PingTelemetry:End of Configurations *******" 
# Calculating no of seconds elapsed after 12 am
secs_after_midnight=`echo $(( $(date "+(10#%H * 60 + 10#%M) * 60 + 10#%S") ))`
echo "`timestamp` PingTelemetry:current_time:$secs_after_midnight(in sec)"

# Function to calculate the start time for first ping burst
calculate_first_test_starttime () {

    sub_window_size=$(( ( $pingtelemetry_endtime - $pingtelemetry_starttime ) / $burst_count ))
    if [ $secs_after_midnight -ge $pingtelemetry_starttime ] && [ $secs_after_midnight -le $pingtelemetry_endtime ]; then        
        testcount_remaining=$(( ( $pingtelemetry_endtime - $secs_after_midnight ) / $sub_window_size ))
        testcount_skipped=$(( $burst_count - $testcount_remaining ))
        echo "`timestamp` PingTelemetry:Skipping $testcount_skipped tests as the time passed the ping telemetry start time"
        pingtelemetry_starttime=$(( ( $testcount_skipped * $sub_window_size ) + $pingtelemetry_starttime ))
        burst_count=$testcount_remaining
        echo "`timestamp` PingTelemetry:Modifying burst_count as $burst_count as the time passed the ping telemetry start time"
        echo "`timestamp` PingTelemetry:pingtelemetry_starttime:$pingtelemetry_starttime (in sec)"
    elif [ $secs_after_midnight -ge $pingtelemetry_endtime ]; then
        skip_test "Test is skipped as window time is crossed"
    fi
    
    # Calculating the sub window size available for each ping test
    echo "`timestamp` PingTelemetry:sub_window_size: $sub_window_size"

    # Calculating the end time for first subwindow
    first_window_end_time=`expr $pingtelemetry_starttime + $sub_window_size`
    echo "`timestamp` PingTelemetry:First window:$pingtelemetry_starttime to $first_window_end_time"

    # Getting a random starttime in the first sub window
    test_starttime="$(( ( RANDOM % ($first_window_end_time - $pingtelemetry_starttime +1 ) ) + $pingtelemetry_starttime ))"
}

# Function to trigger ping test
ping_test () {
    echo "`timestamp` PingTelemetry:Sleep done. Starting ping test, burstCount :$test_count"
    
    # Starting CPU monitoring
    sh /lib/rdk/ping-telemetry-monitor.sh start &
    
    pingtime_start=`echo $(( $(date "+(10#%H * 60 + 10#%M) * 60 + 10#%S") ))`
    # Starting the ping test
    echo "`timestamp` PingTelemetry:PING_CMD:$ping_command -i $ping_interval -c $packet_count -s $ping_packet_size $ping_destination -q"
    $ping_command -i $ping_interval -c $packet_count -s $ping_packet_size $ping_destination -q >> $PINGDATA_FILE
    pingtime_end=`echo $(( $(date "+(10#%H * 60 + 10#%M) * 60 + 10#%S") ))`
    
    # Stopping CPU Monitoring
    sh /lib/rdk/ping-telemetry-monitor.sh stop
    
    # Checking whether ping restart is required, this flag is created during cpu monitoring 
    if [ -f /tmp/ping_restart ]; then
        rm /tmp/ping_restart
        # Doubling the ping interval
        ping_interval=`awk "BEGIN {print $ping_interval * 2; exit}"`
        if [ "$ping_interval" == "1.6" ]; then
            ping_interval=1
        elif [ $ping_interval -ge 16 ]; then
            ping_interval=16
        fi
        echo "`timestamp` PingTelemetry:Restarting the test as ping crossed the CPU usage limit with ping interval:$ping_interval"
        sleep 10
        ping_test

    else
        # Calculating the pingtime and updating the pingdata file
        pingtime_ms=`expr $(( pingtime_end - $pingtime_start )) \* 1000`
        echo "ping_time:$pingtime_ms" >> $PINGDATA_FILE
    fi
    echo "`timestamp` PingTelemetry:Testing done, burstCount:$test_count"
}

calculate_first_test_starttime
echo "`timestamp` PingTelemetry:test_starttime:$test_starttime"

# triggering ping test at scheduled intervals

echo "`timestamp` ******* PingTelemetry:Starting test *******" 
test_count=1
while [ $test_count -le $burst_count ]
do
    echo "`timestamp` PingTelemetry:Next test starttime : $test_starttime, current_time : $secs_after_midnight"
    # Calculating the sleep time uptil the first test
    sleep_time=`expr $test_starttime - $secs_after_midnight`
    if [ $sleep_time -gt 0 ]; then
        echo "`timestamp` PingTelemetry:Sleeping for $sleep_time before the test"
        sleep $sleep_time
    fi    
    
    test_starttime=`expr $test_starttime + $sub_window_size`
    if [ $secs_after_midnight -le $test_starttime ]; then    
        # Checking whether pingTest is enabled, need to check before every burst
        pingTestEnable=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.PingTelemetry.Enable 2>&1 > /dev/null`
        if [ "$pingTestEnable" != "true" ]; then 
            if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]
               then
                  eventSender "MaintenanceMGR" $MAINT_PINGTELEMETRY_ERROR
            fi
            skip_test "Exiting as ping telemetry is disabled"
        fi
        
        # Waiting if device is in standby mode
        while [ "$LIGHTSLEEP_ENABLE" == "true" ] && [ -f /tmp/.standby ]; do
            sleep 120
        done    
        ping_test
    else
        # Condition where current time exceeded the ping test scheduled time, corner case like device goes to standby
        echo "`timestamp` PingTelemetry:Skipping burst_count:$test_count as time exceeded the window"
    fi
    
    # Calculating the current time(after midnight) in seconds
    secs_after_midnight=`echo $(( $(date "+(10#%H * 60 + 10#%M) * 60 + 10#%S") ))`
    test_count=`expr $test_count + 1`
done

echo "`timestamp` PingTelemetry:PingTest is completed for $burst_count bursts"
echo "`timestamp` ******* PingTelemetry:End of test *******" 

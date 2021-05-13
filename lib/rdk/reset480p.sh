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
# Send message to tru2way proxy to stop ocap video/audio
echo -e "t2p:msg setResolution\n{"setResolution" : {"portName" : "HDMI", "resolutionName" : "480p" }}\nt2p:msg" | nc localhost 3773
echo -e "t2p:msg setResolution\n{"setResolution" : {"portName" : "COMPONENT_VIDEO", "resolutionName" : "480p" }}\nt2p:msg" | nc localhost 3773
killall Receiver

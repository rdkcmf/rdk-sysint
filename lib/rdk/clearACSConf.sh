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

if [ $# -ne 1 ]
then
  echo "Usage: clearACSConf.sh <partner_id>"
  exit 1
fi

kill -9 `ps aux | grep -i start.sh | grep -v grep | awk '{print $2}'` &>/dev/null
kill -9 `ps aux | grep -i dimclient | grep -v grep | awk '{print $2}'` &>/dev/null

if [ -e /opt/tr69agent-db ]; then rm -rf /opt/tr69agent-db; fi
if [ -e /opt/secure/tr69agent-db ]; then rm -rf /opt/secure/tr69agent-db; fi
if [ -e /opt/persistent/tr69bootstrap.dat ]; then rm /opt/persistent/tr69bootstrap.dat; fi

#Restart tr69-agent service
systemctl restart tr69agent.service


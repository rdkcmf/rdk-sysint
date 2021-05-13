# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2016 RDK Management, LLC. All rights reserved.
# ============================================================================
. /etc/include.properties
. /etc/device.properties
if [ -f /etc/hosts.default ]; then
  cp /etc/hosts.default /tmp/hosts
fi
echo "127.0.0.1 localhost" >> /tmp/hosts
if [ "$BUILD_TYPE" != "prod" ]; then
    # To update the /etc/hosts
    if [ -f $PERSISTENT_PATH/hosts ] ; then
        cat $PERSISTENT_PATH/hosts >> /tmp/hosts
    fi
fi

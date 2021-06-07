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

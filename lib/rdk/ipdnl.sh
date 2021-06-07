#! /bin/sh
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

set -x
. /etc/include.properties
. /etc/config.properties
. /etc/device.properties

if [ -f $RDK_PATH/utils.sh ];then
     . $RDK_PATH/utils.sh
fi

if [ "$DEVICE_TYPE" = "mediaclient" ];then
RETRY_COUNT=3
TFTP_SVR=$1
UPGRADE_FILE=$2
DOWNLOAD_PATH=$3
PROTO=$4
httpServerConf=$PERSISTENT_PATH"/httpServer.conf"

 if [ $PROTO -eq 1 ]; then
     echo "Transport Protocol: TFTP"
     tftp -g  $1 -r $2 -l $DOWNLOAD_PATH/$2 -b 16384
     ret=$?
     if [ $ret -ne 0 ]; then
	     echo "TFTP failed for image: $UPGRADE_FILE" >> $LOG_PATH/ipdllogfile.txt
	     exit 1
     else
	     echo "TFTP Success $UPGRADE_FILE" >> $LOG_PATH/ipdllogfile.txt
	     exit 0
     fi
 else
     if [ -f $httpServerConf ] && [ "$BUILD_TYPE" != "prod" ]; then
             TFTP_SVR=`grep -v '^[[:space:]]*#' $httpServerConf`
             PORT=8080
     elif [ "$BUILD_TYPE" != "dev" ]; then
             if [ -f /tmp/estb_ipv6 ]; then
                 TFTP_SVR="2001:558:1020:1:250:56ff:fe94:63e4"
             else
                 TFTP_SVR="69.252.105.37"
             fi
	     PORT=10028
     else
	     PORT=8080
     fi
     if [ -f /tmp/estb_ipv6 ]; then
         imageHTTPURL="http://[$TFTP_SVR]:$PORT/Images/$UPGRADE_FILE"
     else
         imageHTTPURL="http://$TFTP_SVR:$PORT/Images/$UPGRADE_FILE"
     fi
     echo  "PROTO: $proto , IMAGE URL= $imageHTTPURL" >> $LOG_PATH/ipdllogfile.txt
     ret=1
     retryCount=0
     while [ $ret -ne 0 ] 
     do 
	 retryCount=$((retryCount + 1))
         # Clean up of existing files before image download retries
         if [ -d "$DOWNLOAD_PATH" ] ; then
             model_num=$(getModel)
             FILE_EXT=$model_num*.bin*
             rm $DOWNLOAD_PATH/$FILE_EXT
         fi
         curl -fgLo $DOWNLOAD_PATH/$UPGRADE_FILE $imageHTTPURL
	 ret=$?
	 echo $ret
         if [ $ret -ne 0 ]; then
               echo "Local image Download Failed..Retrying" >> $LOG_PATH/ipdllogfile.txt
	       if [ $retryCount -ge $RETRY_COUNT ] ; then
                    echo "$RETRY_COUNT tries failed. Giving up local download" >> $LOG_PATH/ipdllogfile.txt
                    exit 1
               fi
         fi
     done
  fi
  echo "$UPGRADE_FILE Download Completed.!" >> $LOG_PATH/ipdllogfile.txt
  sync
else
if [ -f /lib/rdk/ipDownload_soc.sh ];then
    . /lib/rdk/ipDownload_soc.sh
fi
if [ $# -ne 3 ]; then
     echo "USAGE: $0 $TARFNAME $MD5FNAME $FILE_NAME"
fi

TARFNAME=$1
MD5FNAME=$2

buildType=$BUILD_TYPE
#initialise the call and cleanup
if [ $buildType = "vbn" ] ; then
     mkdir -p /opt/usb
     mount /dev/sda /opt/usb
     sync
     cd /opt/usb
fi
data=""
sdx=""
data=cat /proc/cmdline | grep sdb
echo data = $data
if test -n "$data"; then
      sdx="sdb"
      echo "booted from flash Drive: $sdx"
else
      sdx="sda"
      echo "booted from disk Drive: $sdx"
fi
if [ "$sdx" ="sdb" ] ; then
      mkdir -p /tmp/mnt/diska3
      mount /dev/sda3 /tmp/mnt/diska3
      cd /tmp/mnt/diska3
else
      cd /
fi
echo 10 > /opt/.reboot
sync
killall mpeos-main 2> /dev/null
sync

rm .prev.tgz *.tgz
mv .curr.tgz .prev.tgz

#Download the tar file
sync; curl -fgLO $TARFNAME; sync; sleep 2;

#Download the md5 file
sync; curl -fgLO $MD5FNAME; sync; sleep 2;
sync
#Move the file to current tarball file
mv $3 .curr.tgz
sync
#finish the download
rm -rf  *.* DSG-Package* settings dsg_dir env mnt/* r* lib/modules etc usr/local opt_back .adobe .macromedia .ssh lib/libsec* 
# Device specific cleanup
deviceCleanup

rm -rf  /root/runXRE /root/runRI /root/pWait.sh
# Device specific pre cleanup
device_preCleanup
sync; sleep 2
nice -n -20 tar zxf .curr.tgz
sync; sleep 2
nice -n -20 tar zxf rng150_fs.tgz
sync; sleep 2
# Device specific post cleanup
device_postCleanup
sync

# Flash the kernel
flashTheKernel

fi

exit 0

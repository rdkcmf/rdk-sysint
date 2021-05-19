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


. /etc/include.properties
. /etc/device.properties

if [ -f /etc/env_setup.sh ]; then
    . /etc/env_setup.sh
fi

. /etc/config.properties

PROVISION_PROPERTIES=/etc/provision.properties
RT_PROTOCOL_VERSION=$(sed -n 's/^RT_PROTOCOL_VERSION=//p' $PROVISION_PROPERTIES)
if [ ! -z $RT_PROTOCOL_VERSION ]; then
  . ${PROVISION_PROPERTIES}
else
  RT_PROTOCOL_VERSION="1"
fi

DISABLE_RTV2=`tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.SocProvisioning.disableCredentialsPrefetchCaching 2>&1`

if [ -z $RT_PROTOCOL_LOCK ] || [ ! $RT_PROTOCOL_LOCK = "true" ]; then
  if [ $DISABLE_RTV2 = "true" ]; then
    echo "Forcing RT_PROTOCOL_VERSION 1"
    RT_PROTOCOL_VERSION="1"
  fi
fi

if [ -f /SetEnv.sh ]; then
  . /SetEnv.sh
fi

# C0
# skip running if socprovisioning is not supported
if [ -f /opt/nosocprov ]; then
  echo "Skip running socprovisioning" >>$SOCPROVSTARTLOG
  exit 1
fi

SOCPROVSTARTLOG="$LOG_PATH/socprov_start.log"

# PROTOCOL-SPECIFIC PARTS
provision_v1() {
  isFKPSReachable() {
    FKPS_SCRIPT_LOCATIONS=("/sysint/fkps.sh" "/sysint/utils/fkps.sh" "/lib/rdk/fkps.sh")
    FKPS_SCRIPT=""
    FKPS_IS_REACHABLE=0

    for location in ${FKPS_SCRIPT_LOCATIONS[*]}; do
      if [ -f $location ]; then
        FKPS_SCRIPT=$location
        break
      fi
    done

    if [ ! -z $FKPS_SCRIPT ]; then
      FKPS_URLS=("$(/bin/sh -c ". $FKPS_SCRIPT; getFKPSBURL;")")
      for url in ${FKPS_URLS[*]}; do
        case "$(curl -H "Connection: close" -s --max-time 2 -I $url | sed 's/^[^ ]*  *\([0-9]\).*/\1/; 1q')" in
        [234]) FKPS_IS_REACHABLE=1 ;;
        esac
      done
    fi
    return $FKPS_IS_REACHABLE
  }
  # end of function

  BINFILE="socprovisioning"
  PACKAGE_VERSION_FILE="/opt/drm/currentPackageVersion.txt"

  if [ "$1" == "socprovisioning-crypto" ]; then
    BINFILE=$1
    PACKAGE_VERSION_FILE="/opt/drm/crypto/currentPackageVersion.txt"
  fi

  if [ ! -f /etc/os-release ]; then
    SOC_PROVISION_BIN=/etc/$BINFILE
  else
    SOC_PROVISION_BIN=/usr/bin/$BINFILE
  fi

  case "$1" in
  $BINFILE) CMDLINE=${@#$1} ;;
  *) CMDLINE=${@} ;;
  esac

  BOOTUP_MARKER=/tmp/$BINFILE-bootup
  if [ -f $BOOTUP_MARKER ] && [ -z $CMDLINE ]; then
    # In legacy or rt.v1 mode, the app starts only at system startup or when called with additional parameters like --reprovision. Periodical invokations ignored"
    echo "Not launching $BINFILE. Only boot-up-time invocation is supported in RT V1 mode."
    exit 0
  else
    touch $BOOTUP_MARKER
    echo "$(date +%s)" >$BOOTUP_MARKER
  fi

  if [ ! -d /opt/persistent/adobe ]; then
    mkdir -p /opt/persistent/adobe
  fi

  if [ ! -f /etc/os-release ]; then
    if [[ "$DEVICE_NAME" = "RNG150" ]]; then
      # waiting for nexus device initialized
      while [ ! -f /proc/brcm/core ]; do
        sleep 2
      done
    fi
  fi

  if [ ! -f /etc/os-release ]; then
    # Checking the dependency module before startup
    nice sh $RDK_PATH/iarm-dependency-checker "socprovisioning"
  fi

  export LD_LIBRARY_PATH="/usr/local/Qt/lib:/usr/local/lib:$LD_LIBRARY_PATH"
  if [ -d /usr/local/lib/opensslg ]; then
    export LD_LIBRARY_PATH="/usr/local/lib/opensslg:$LD_LIBRARY_PATH"
  fi

  if [ -f $SOC_PROVISION_BIN ]; then

    # Send a curl HEAD request to FKPS Server to check if it's responding before launching socprovisioning.
    # Do a retry by increasing the interval by 1 sec upto 60 seconds.

    isFKPSReachable
#   FKPS Reachability test will be performed not more than ATTEMPTS_MAX times with a Fibonacci delay capped to FKPS_WAIT_MAX_SEC seconds
#   e.g, 1, 2, 3, 5, ..., FKPS_WAIT_MAX_SEC, FKPS_WAIT_MAX_SEC, FKPS_WAIT_MAX_SEC ... (ATTEMPTS_MAX attempts in total)
    ATTEMPTS_MAX=8
    FKPS_WAIT_MAX_SEC=55
    timeFKPSwait0=1
    timeFKPSwait=2
    attempt=0
    while [ $FKPS_IS_REACHABLE -eq 0 ]  && [ $attempt -lt $ATTEMPTS_MAX ]; do
      if [ ! -f /etc/os-release ]; then
        echo "FKPS is unreachable, waiting for secs: $timeFKPSwait" >>$SOCPROVSTARTLOG
      else
        echo "FKPS is unreachable, waiting for secs: $timeFKPSwait"
      fi
      sleep $timeFKPSwait
      if [ $timeFKPSwait -lt $FKPS_WAIT_MAX_SEC ]; then
        tmpFKPSwait=$timeFKPSwait
        timeFKPSwait=$((timeFKPSwait + timeFKPSwait0))
        timeFKPSwait0=$tmpFKPSwait
      fi
      attempt=$((attempt + 1))
      isFKPSReachable
    done

    if [ $FKPS_IS_REACHABLE -eq 0 ]; then
      echo "Stopping FKPS retries"
    fi

    printf "FKPS reachability test:"
    printf " server is ";  [ $FKPS_IS_REACHABLE -eq 0 ] && printf "unreachable" || printf "reachable"
    printf "; wait attempts: %d out of %d" $attempt $ATTEMPTS_MAX
    echo ""

    if [ ! -f /etc/os-release ]; then
      $SOC_PROVISION_BIN $CMDLINE 2>>$SOCPROVSTARTLOG >>$SOCPROVSTARTLOG
    else
      $SOC_PROVISION_BIN $CMDLINE -c log/path -
    fi

    ret=$?
    EX_DATAERR=65
    EX_NOHOST=68
    EX_UNAVAILABLE=69

    status_check=false
    for i in $*; do
      if [ $i = "--status" ]; then
        status_check=true
        break
      fi
    done

    # SocProv reports EX_DATAERR for all internal errors like missing model number, clock not set.
    # All these internal errors will have a fixed retry interval.

    # SocProv reports EX_NOHOST for any network errors including timeout from FKPS-RT Server
    # SocProv reports EX_UNAVAILABLE for errors related to internal processing from FKPS-RT server.
    # All EX_UNAVAILABLE & EX_NOHOST errors will have a fibanocci series retry interval (1,2,3,5,8... seconds)
    # This is to ensure STBs don't hammer the FKPS-RT servers.
    ATTEMPTS_MAX=8
    attempt=1
    time1=2
    time2=3
    while [ $attempt -lt $ATTEMPTS_MAX ] && ([ ! -f $PACKAGE_VERSION_FILE ] || [ $ret -eq $EX_UNAVAILABLE ] || [ $ret -eq $EX_NOHOST ] || [ $ret -eq $EX_DATAERR ]); do
      if [ $status_check = true ]; then
        break
      fi

      temp=$((time1 + time2))
      time1=$time2
      time2=$temp
      attempt=$((attempt + 1))

      # if it's EX_DATAERR because of bad input data like model number or clock not set,
      # then retry every 2 seconds.
      if [ $ret -eq $EX_DATAERR ]; then
        time1=2
      fi
      if [ ! -f /etc/os-release ]; then
        echo "Program terminated with code $ret, waiting for secs: $time1 (attempt $attempt out of $ATTEMPTS_MAX)" >>$SOCPROVSTARTLOG
      else
        echo "Program terminated with code $ret, waiting for secs:  $time1 (attempt $attempt out of $ATTEMPTS_MAX)"
      fi
      sleep $time1
      if [ ! -f /etc/os-release ]; then
        $SOC_PROVISION_BIN $CMDLINE 2>>$SOCPROVSTARTLOG >>$SOCPROVSTARTLOG
      else
        $SOC_PROVISION_BIN $CMDLINE -c log/path -
      fi
      ret=$?
    done

    if [ $ret -ne 0 ]; then
      echo "Stopping FKPS retries"
    fi

    echo "Done with running $SOC_PROVISION_BIN; exit code $ret after $attempt attempt(s)"

    if [ ! -d /opt/drm ]; then mkdir -p /opt/drm; fi
    if [ "$ENABLE_MULTI_USER" = "true" ]; then
      if [ ! -f /etc/os-release ]; then
        chown -R restricteduser /opt/drm/*
      fi
    fi
  else
    if [ ! -f /etc/os-release ]; then
      echo "Have no socprovisioning binary installed" >>$SOCPROVSTARTLOG
    else
      echo "Have no socprovisioning binary installed"
    fi
  fi
} #v1

provision_v2() {
  isThunderReachable() {
    THUNDER_IS_REACHABLE=0
    THUNDER_SECURITY_ENABLED=$(curl -s http://127.0.0.1:9998/Service/Controller/Configuration/Controller | grep -c Security)
    if [ $THUNDER_SECURITY_ENABLED = "1" ]; then
      token=$(/usr/bin/WPEFrameworkSecurityUtility | grep token | cut -f4 -d "\"")
      curl -s -H "Content-Type: application/json"  -H "Authorization: Bearer $token"  -X POST -d '{"jsonrpc":"2.0","id":"3","method": "Controller.1.activate", "params":{"callsign":"org.rdk.AuthService"}}' http://127.0.0.1:9998/jsonrpc > /dev/null 2>&1
      status=$(curl -s -H "Content-Type: application/json"  -H "Authorization: Bearer $token" -X POST -d '{"jsonrpc":"2.0","id":"3","method": "org.rdk.AuthService.1.getActivationStatus"}' http://127.0.0.1:9998/jsonrpc | cut -f12 -d "\"")
    else
      curl -s -H "Content-Type: application/json" -X POST -d '{"jsonrpc":"2.0","id":"3","method": "Controller.1.activate", "params":{"callsign":"org.rdk.AuthService"}}' http://127.0.0.1:9998/jsonrpc > /dev/null 2>&1
      status=$(curl -s -H "Content-Type: application/json" -X POST -d '{"jsonrpc":"2.0","id":"3","method": "org.rdk.AuthService.1.getActivationStatus"}' http://127.0.0.1:9998/jsonrpc | cut -f12 -d "\"")
    fi
    if [ ! -z "$status" ]; then
      THUNDER_IS_REACHABLE=1
    fi
    return $THUNDER_IS_REACHABLE
  }

  isAlreadyRunning() {
    ALREADY_RUNNING=0
    local CNT=("$(/bin/sh -c "ps aux | grep -ic '$1 '")")
    if [ $(($CNT + 0)) -gt 4 ]; then
      ALREADY_RUNNING=1
    fi
  }

  BINFILE="socprovisioning"
  if [ "$1" = "socprovisioning-crypto" ]; then
    BINFILE=$1
  fi

  case "$BINFILE" in
  "socprovisioning") TYPE="HARDWARE" ;;
  "socprovisioning-crypto") TYPE="CRYPTANIUM" ;;
  esac

  BOOTUP_MARKER=/tmp/$BINFILE-bootup
  if [ ! -f $BOOTUP_MARKER ]; then
    BOOTUP="-c rt/bootup true"
    touch $BOOTUP_MARKER
  fi

  case "$1" in
  "$BINFILE") CMDLINE=${*#$1} ;;
  *) CMDLINE=${*} ;;
  esac

  # also updated later
  if [ ! -z "$BOOTUP" ]; then
    CMDLINE="${CMDLINE} ${BOOTUP}"
  fi

  if [ ! -f /etc/os-release ]; then
    SOC_PROVISION_BIN=/etc/$BINFILE
  else
    SOC_PROVISION_BIN=/usr/bin/$BINFILE
  fi

  REPROVISION=false
  for i in "$@"; do
    if [ $i = "--reprovision" ]; then
      REPROVISION=true
      break
    fi
    if [ $i = "--status" ]; then
      RUN_MARKER=true
    fi
    if [ $i = "--refresh" ]; then
      RUN_MARKER=true
    fi
  done

  # Recreating the missing drm storage dirs
  # Setting the correct access rights to drm files
  if [ ! -z "$TYPE" ]; then
    array_name=$TYPE
    DRM_DIRS=$array_name[@]
    DRM_DIRS=("${!DRM_DIRS}")
    for drmDir in ${DRM_DIRS[*]}; do
      if [ ! -z "$drmDir" ]; then
        if [ ! -d $drmDir ]; then
          mkdir -p $drmDir
          echo "$drmDir was missing (recreated)"
        fi
      fi
      if [ "$ENABLE_MULTI_USER" = "true" ]; then
        if [ ! -f /etc/os-release ]; then
          chown -R restricteduser $drmDir/*
        fi
      fi
    done
    CONF_DIRS="-c storage/drmFolder  ${DRM_DIRS[0]} -c storage/drmFolderBackup ${DRM_DIRS[1]} -c storage/drmPrefetchFolder ${DRM_DIRS[2]} -c storage/drmPrefetchFolderBackup ${DRM_DIRS[3]}"
    CMDLINE="${CMDLINE} ${CONF_DIRS}"
  fi

  REFRESH_TIME_FILE=${DRM_DIRS[0]}/rtrefresh-epoch
  if [ -f $REFRESH_TIME_FILE ]; then
    RT_MD5SUM_CALC="$(md5sum $REFRESH_TIME_FILE | awk '{print $1}')"
    read -r RT_MD5SUM_STOR <"$REFRESH_TIME_FILE.md5"
    if [ ! "$RT_MD5SUM_CALC" = "$RT_MD5SUM_STOR" ]; then
        echo "Hash sum error of $REFRESH_TIME_FILE. Corrupted file removed. The backoff time will be counted as 0"
        rm $REFRESH_TIME_FILE
        if [ -f "$REFRESH_TIME_FILE.md5" ]; then
          rm "$REFRESH_TIME_FILE.md5"
        fi
    fi
  fi

  timeWait=1

  isThunderReachable # THunder reachability check
  NB_THUNDER_WAIT=15
  while [ $THUNDER_IS_REACHABLE -eq 0 ] && [ $NB_THUNDER_WAIT -gt 0 ]; do
    if [ ! -f /etc/os-release ]; then
      echo "THUNDER is unreachable, waiting $timeWait more sec..." >>$SOCPROVSTARTLOG
    else
      echo "THUNDER is unreachable, waiting $timeWait more sec..."
    fi
    sleep $timeWait

    if [ $timeWait -lt 60 ]; then
      timeWait=$((timeWait + 1))
    fi
    if [ $NB_THUNDER_WAIT -gt 0 ]; then
      NB_THUNDER_WAIT=$((NB_THUNDER_WAIT - 1))
    fi
    isThunderReachable
    echo $NB_THUNDER_WAIT
  done
  if [ $THUNDER_IS_REACHABLE -eq 0 ]; then
    echo "Thunder is NOT REACHABLE. Exiting..."
    exit 1
  fi
  printf "Thunder is REACHABLE with "
  if [ $THUNDER_SECURITY_ENABLED = "1" ]; then
    printf "SECURITY ENABLED"
  else
    printf "SECURITY DISABLED"
  fi
  echo ""

  isAlreadyRunning $BINFILE # Wait for another instance to terminate first
  timeWait=5
  NB_INSTANCE_WAIT=120
  TOT_TIME_WAIT=$(printf %d "$(($NB_INSTANCE_WAIT * $timeWait))")
  while [ $ALREADY_RUNNING -eq 1 ] && [ $NB_INSTANCE_WAIT -gt 0 ]; do
    if [ ! -f /etc/os-release ]; then
      echo "Another $BINFILE is running, waiting $timeWait more sec..." >>$SOCPROVSTARTLOG
    else
      echo "Another $BINFILE is running, waiting $timeWait more sec..."
    fi
    sleep $timeWait

    if [ $timeWait -lt 60 ]; then
      timeThunderWait=$((timeThunderWait + 1))
    fi
    if [ $NB_INSTANCE_WAIT -gt 0 ]; then
      NB_INSTANCE_WAIT=$((NB_INSTANCE_WAIT - 1))
    fi
    isAlreadyRunning $BINFILE
    echo $NB_INSTANCE_WAIT
  done
  if [ $ALREADY_RUNNING -eq 1 ]; then
    echo "It looks like another $BINFILE instance is still running after $TOT_TIME_WAIT wait cycles. Is it stuck? Exiting"
    exit 1
  fi

  printf "Current conditions:"
  printf " BOOTUP flag is ";  [ ! -z "$BOOTUP" ] && printf "present" || printf "not set"
  printf "; REPROVISION is ";  [ ! -z "$REPROVISION" ] && echo -n $REPROVISION || printf "not set"
  printf "; RUN_MARKER is ";  [ ! -z "$RUN_MARKER" ] && echo -n $RUN_MARKER || printf "not set"
  echo ""
  if [ "$RUN_MARKER" = "true" ] || [ "$REPROVISION" = "true" ] || [ ! -z "$BOOTUP" ]; then
    echo "Launching $BINFILE"
    if [ ! -f /etc/os-release ]; then
      # Checking the dependency module before startup
      nice sh $RDK_PATH/iarm-dependency-checker "socprovisioning"
    fi

    if [ -f $SOC_PROVISION_BIN ]; then
      if [ ! -f /etc/os-release ]; then
        $SOC_PROVISION_BIN $CMDLINE 2>>$SOCPROVSTARTLOG >>$SOCPROVSTARTLOG
      else
        $SOC_PROVISION_BIN $CMDLINE -c log/path -
      fi
    else
      if [ ! -f /etc/os-release ]; then
        echo "$BINFILE not found" >>$SOCPROVSTARTLOG
      else
        echo "$BINFILE not found"
      fi
    fi
  else
      echo "Not launching $BINFILE. No suitable conditions."
  fi
} #v2

case $RT_PROTOCOL_VERSION in
"1") provision_v1 "${@}" ;;
"2") provision_v2 "${@}" ;;
esac

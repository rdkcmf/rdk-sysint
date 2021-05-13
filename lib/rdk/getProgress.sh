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
. /etc/device.properties

resetErrorTimer() 
{
    rm -f /tmp/$1
}

checkErrorTime()
{
  CHECKTIME=`date +%s`
  if [ -f /tmp/$1 ]; then
    LASTCHECK=`cat /tmp/$1`
  else
    echo $CHECKTIME > /tmp/$1
    LASTCHECK=$CHECKTIME
  fi

  if [ $# -ge 2 ]; then
    echo `expr '(' $CHECKTIME - $LASTCHECK ')' '>' $2`
  else 
    echo `expr '(' $CHECKTIME - $LASTCHECK ')' '>' 480`
  fi
}

count=$1
gzEnabled=0
if [ -f /opt/gzenabled ] ; then
  gzEnabled=`cat /opt/gzenabled`
fi
if [ $gzEnabled -gt 0 ] ; then
  if [ -f /tmp/rdk_startup_complete ] ; then
    echo -1
    exit 0
  fi
  
  rdkErrorCode=0
  if [ -f /tmp/rdk_error ] ; then
    # there is no need to check for network or xre errors if there is another error being shown
    rdkErrorCode=`cat /tmp/rdk_error`
    if [ $rdkErrorCode -ne 12 ] && [ $rdkErrorCode -ne 13 ] && [ $rdkErrorCode -ne 11 ] && [ $rdkErrorCode -ne 0 ] ; then
       # if an error besides 12 (internet) or 13 (xre) is being shown then reset the internet and xre timeout
       resetErrorTimer "rdk_check_net"
       resetErrorTimer "rdk_check_xre"
       echo $rdkErrorCode
       exit 0
    fi
  fi

  route | grep "default" | grep -v grep &> /dev/null
  if [  $? -ne 0 ] ; then
    if  [ $(checkErrorTime "rdk_check_net") -gt 0 ] ; then 
      # check if there was an update in the system clock
      if [ -f /tmp/stt_received ] &&  [ ! -f /tmp/rdk_clock_updated ] ; then
        touch /tmp/rdk_clock_updated
        if [ -f /tmp/rdk_error ] ; then
          rm /tmp/rdk_error
        fi
        resetErrorTimer "rdk_check_net"
        resetErrorTimer "rdk_check_xre" 
      else
        #show RDK-10000 if no internet but moca is connected
        mocaNetworkUp=0
        if [ -f /lib/rdk/isMocaNetworkUp.sh ] ; then
          mocaNetworkUp=`/lib/rdk/isMocaNetworkUp.sh`
          if [ $mocaNetworkUp -eq 1 ] ; then
            echo 14 > /tmp/rdk_error
          else
            echo 11 > /tmp/rdk_error
          fi
        else
          echo 12 > /tmp/rdk_error
        fi
      fi

   elif [ -f /lib/rdk/isMocaNetworkUp.sh ]; then
      if  [ $(checkErrorTime "rdk_check_net" 240) -gt 0 ] ; then
        mocaNetworkUp=`/lib/rdk/isMocaNetworkUp.sh`
        if [ $mocaNetworkUp -eq 1 ] ; then
          echo 14 > /tmp/rdk_error
        else
          echo 11 > /tmp/rdk_error
        fi
      fi
    fi

    resetErrorTimer "rdk_check_xre"
    echo $rdkErrorCode
    exit 0
  elif [ ! -f /tmp/rdk_xre_is_connected ]; then
      if  [ $(checkErrorTime "rdk_check_xre") -gt 0 ] ; then
          if [ -f /tmp/stt_received ] &&  [ ! -f /tmp/rdk_clock_updated ] ; then
              touch /tmp/rdk_clock_updated
              if [ -f /tmp/rdk_error ] ; then
                  rm /tmp/rdk_error
              fi
              resetErrorTimer "rdk_check_net"
              resetErrorTimer "rdk_check_xre"
          else
              # if xre is still not connected after an internet connection then report an error
              echo 13 > /tmp/rdk_error
          fi
      fi
      echo $rdkErrorCode
      exit 0
  fi
  resetErrorTimer "rdk_check_net"
  resetErrorTimer "rdk_check_xre"
  echo $rdkErrorCode
  exit 0
elif [ "$DEVICE_TYPE" = "hybrid" ]; then
     if  [ $count -eq 0 ]; then
        if [ -f /tmp/stage1 ] ; then
                echo $((count+1))
        else
                echo $count
        fi
     elif [ $count -eq 1 ]; then
        if [ -f /tmp/stage2 ] ; then
                echo $((count+1))
        else
                echo $count
        fi
     elif [ $count -eq 2 ]; then
        if [ -f /tmp/stage3 ] ; then
            echo $((count+1))                                        
         else                                                         
            echo $count                                              
         fi 
     elif [ $count -eq 3 ]; then
        if [ -f /tmp/stage4 ] ; then
                echo $((count+1))
        else
                echo $count
        fi
     else
        echo $((count+1))
     fi
else
<<ALWAYS_INCREMENT
    if  [ $count -eq 0 ]; then
        echo $((count+1))
    elif [ $count -eq 1 ]; then
        route | grep "default" | grep -v grep > /dev/null 2>/dev/null
        if [  $? -eq 0 ]; then
            echo $((count+1))
        else
            echo $count
        fi
    elif [ $count -eq 2 ]; then
         rm /opt/upnp                                                 
         cd /opt                                                      
         wget http://127.0.0.1:50050/upnp                             
         upnpCheck=`cat /opt/upnp | grep "videoStreamInit"`           
         if [  $? -eq 0  ]; then
            echo $((count+1))                                        
         else                                                         
            echo $count                                              
         fi 
    elif [ $count -eq 3 ]; then
         echo $((count+1))
    else
        echo $((count+1))
    fi
ALWAYS_INCREMENT
echo $((count+1))
fi

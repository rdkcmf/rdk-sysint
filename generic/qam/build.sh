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

set +x
echo $COMBINED_ROOT
echo '**************************************************'
echo '***           sysint build starts              ***'
echo '**************************************************'

###########################################################
#               SI build Enviornment Setup
###########################################################
export BUILD_PATH=${RDK_PROJECT_ROOT_PATH}/${RDK_COMPONENT_NAME}
#export COMBINED_ROOT=${BUILD_PATH}
export COMBINED_ROOT=${BUILD_PATH}/generic/qam
export FSROOT=${RDK_FSROOT_PATH}
export BUILD_CONFIG=$2

echo BUILD_PATH=${BUILD_PATH}
echo COMBINED_ROOT=${COMBINED_ROOT}
echo FSROOT=${FSROOT}

#sysint_dir="${COMBINED_ROOT}/sysint"
if [ "${COMBINED_ROOT}" != "" ]; then
     sysint_dir="${COMBINED_ROOT}"
else
     sysint_dir="${BUILD_PATH}"
fi
soc_dir="${sysint_dir}/soc"
#soc_dir="${BUILD_PATH}/soc
conf_dir="${sysint_dir}/build/build_conf"
script_dir="${soc_dir}/lib/rdk"
content_of_initd=${conf_dir}/content_of_initd
init_script_location=${soc_dir}/etc/init.d

# Select the BUILD TYPE
if [ ${BUILD_CONFIG} != "" ]; then
          build_type="x${BUILD_CONFIG}"
          build_type1="${BUILD_CONFIG}"
          echo "BUILD_CONFIG: ${BUILD_CONFIG}"
elif [ "$2" != "" ]; then
          build_type="x$2"
          build_type1="$2"
          echo "Arg 2: ${2}"
else
          echo "Default Build Type..!"
          build_type="xAll"
          build_type1="All"
fi


if [ $1 == "install" ];then
     # Creating the WORK PATH for SI build
     mkdir -p ${soc_dir} || exit 1
     rm -rf ${soc_dir}/*
     mkdir -p $FSROOT/sysint

#     cp -r --suffix=".svn" --backup=off ${sysint_dir}/generic/* ${soc_dir}
#     cp -r --suffix=".svn" --backup=off ${sysint_dir}/devspec/* ${soc_dir}
     cp -r --suffix=".svn" --backup=off ${BUILD_PATH}/generic/* ${soc_dir}
     cp -r --suffix=".svn" --backup=off ${BUILD_PATH}/devspec/* ${soc_dir}
     #TODO cp -rf $COMBINED_ROOT/sysint/device_specific/authentication  .
     chmod 775 -R ${soc_dir}/*

       echo "build Type: ${build_type}"

     case "$build_type" in
      'xheadlessmediaclient' )
        echo "Build type: headlessmediaclient (hlmc)"
        cp -f "${content_of_initd}_hlmc" "${content_of_initd}" || exit 1
        cp $COMBINED_ROOT/generic/lib/rdk/getProgress.sh $FSROOT/sysint
        #cp -f ${script_dir}/start_upnp_hlmc.sh ${script_dir}/start_upnp.sh || exit 1
        ;;
      'xmediaclient' )
        echo "Build type: mediaclient (mc)"
#        cp -f "${content_of_initd}_mc" "${content_of_initd}" || exit 1
        cp $COMBINED_ROOT/generic/lib/rdk/getProgress.sh $FSROOT/sysint
        #cp -f ${script_dir}/runXRE_mc ${script_dir}/runXRE || exit 1
        #cp -f ${script_dir}/start_upnp_mc.sh ${script_dir}/start_upnp.sh || exit 1
        ;;
      'xAll' )
        echo "Build type: All (default)"
        cp $COMBINED_ROOT/generic/lib/rdk/getProgress.sh $FSROOT/sysint
        cp $COMBINED_ROOT/generic/lib/rdk/getNumberOfStartupSteps.sh $FSROOT/sysint
        ;;
      *)
        echo "ERROR! Build type $build_type is invalid!"
        ;;
     esac
     cp $COMBINED_ROOT/generic/lib/rdk/getProgress.sh $FSROOT/sysint
     cp $COMBINED_ROOT/generic/lib/rdk/getNumberOfStartupSteps.sh $FSROOT/sysint


     echo '**************************************************'
     echo '***      sysint symbolic links generating      ***'
     echo '**************************************************'

     # delete symlinks folder
     if [ -f ${soc_dir}/etc/rc3.d ]; then
          rm -rf ${soc_dir}/etc/rc3.d
     fi

     # copy only needed services
     if [ ! -f $content_of_initd ]; then
          echo "ERROR: $content_of_initd does not exists!"
     else
          #delete files those do not exists in 
          for input in `ls $init_script_location`; do
              ret=`grep -w $input $content_of_initd`
              if [ $? -eq 1 ] ; then
                   rm -rf $init_script_location/$input
              fi
          done
     fi
     # create all dbs and symlinks
     cur_dir=`pwd`
     cd $init_script_location
     echo $init_script_location
     if [ -e /sbin/insserv ]; then
         /sbin/insserv -vd -c ${conf_dir}/insserv.conf -p `pwd` `pwd`/* 
     elif [ -e /usr/lib/insserv/insserv ]; then
         /usr/lib/insserv/insserv -vd -c ${conf_dir}/insserv.conf -p `pwd` `pwd`/*
     else
         echo "ERROR: insserv is missing!"
         exit 1 
     fi

     # clean up
     #rm -rf ${conf_dir}
     #rm ${soc_dir}/build.sh

     #remove old /etc/init.d/ and /etc/rc3.d/ folders from box root file system
#     rm -rf $FSROOT/etc/init.d/ $FSROOT/etc/rc3.d/
#     rm -rf $FSROOT/etc/rc3.d/S96Httpd
     # copy prepared sysint to image
     find $COMBINED_ROOT/soc/ -name ".svn" -exec rm -rf {} \;
     if [ -d $COMBINED_ROOT/soc/utils ]; then
          rm -rf $COMBINED_ROOT/soc/utils
     fi

     # Copy the final SI scripts to the FSROOT
     cp $COMBINED_ROOT/soc/etc/rc3.d/* $FSROOT/etc/init.d/     
     
     cp $COMBINED_ROOT/generic/etc/init.d/crash-backup $FSROOT/etc/init.d/
     cp $COMBINED_ROOT/generic/etc/init.d/lighttpd $FSROOT/etc/init.d/
     cp $BUILD_PATH/generic/etc/init.d/iarm-bus-startup $FSROOT/etc/init.d/
     cp $COMBINED_ROOT/generic/etc/init.d/rmf-streamer $FSROOT/etc/init.d/
     cp $COMBINED_ROOT/generic/etc/init.d/setupfolders $FSROOT/etc/init.d/
     cp $COMBINED_ROOT/generic/etc/init.d/dmesg-log-service $FSROOT/etc/init.d/
     cp $COMBINED_ROOT/generic/etc/init.d/network-interface-startup $FSROOT/etc/init.d/
     cp $COMBINED_ROOT/generic/etc/init.d/swupdate $FSROOT/etc/init.d/
     cp $COMBINED_ROOT/generic/etc/init.d/scheduled-reboot $FSROOT/etc/init.d/
     cp $COMBINED_ROOT/generic/etc/init.d/monitoring-services-startup $FSROOT/etc/init.d/
     cp $COMBINED_ROOT/generic/etc/init.d/init_utilities $FSROOT/etc/init.d/

     cp $BUILD_PATH/generic/etc/common.properties $FSROOT/etc/
     cp $BUILD_PATH/generic/etc/include.properties $FSROOT/etc/

     mkdir -p $FSROOT/lib/rdk/hooks
     cp $COMBINED_ROOT/generic/lib/rdk/init-functions $FSROOT/lib/rdk/
     cp $COMBINED_ROOT/generic/lib/rdk/uploadDumps.sh $FSROOT/lib/rdk/
     cp $COMBINED_ROOT/generic/lib/rdk/utils.sh $FSROOT/lib/rdk/
     cp $COMBINED_ROOT/generic/lib/rdk/clearCoredumps.sh $FSROOT/lib/rdk/
     cp $COMBINED_ROOT/generic/lib/rdk/deviceInitiatedFWDnld.sh $FSROOT/lib/rdk/
     cp $COMBINED_ROOT/generic/lib/rdk/commonUtils.sh $FSROOT/lib/rdk/
     cp $COMBINED_ROOT/generic/lib/rdk/snmpUtils.sh $FSROOT/lib/rdk/
     cp $COMBINED_ROOT/generic/lib/rdk/startSSH.sh $FSROOT/lib/rdk/
     cp $COMBINED_ROOT/generic/lib/rdk/runSnmp.sh $FSROOT/lib/rdk/
     cp $COMBINED_ROOT/generic/lib/rdk/interfaceCalls.sh $FSROOT/lib/rdk/
     cp $COMBINED_ROOT/generic/lib/rdk/monitorRMF.sh $FSROOT/lib/rdk/
     cp $COMBINED_ROOT/generic/lib/rdk/runRMFStreamer $FSROOT/lib/rdk/

     sed -i s/DEVICE_TYPE=/DEVICE_TYPE=$build_type1/ $FSROOT/etc/device.properties

     # Final SI scripts Arrangments
     sh ${sysint_dir}/build/fileCopy.sh

     cd ${cur_dir}
     echo "********** sysint configure end ***********"

fi

exit 0

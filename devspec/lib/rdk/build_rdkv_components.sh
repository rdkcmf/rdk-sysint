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

execute_component() {

#BD1004- Removed licensed components
case $2 in
    "gst-plugins-base")
        mkdir gst-plugins-base
        cd gst-plugins-base
        curl -O https://gstreamer.freedesktop.org/src/gst-plugins-base/gst-plugins-base-1.4.4.tar.xz     
        tar -xvf gst-plugins-base-1.4.4.tar.xz
        cd gst-plugins-base-1.4.4
        autoreconf -i
        ./configure --build=x86_64-linux --host=i586-rdk-linux --target=i586-rdk-linux --prefix=/usr --exec_prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin --libexecdir=/usr/lib/gst-plugins-base --datadir=/usr/share --sysconfdir=/etc --sharedstatedir=/com --localstatedir=/var --libdir=/usr/lib --includedir=/usr/include --oldincludedir=/usr/include --infodir=/usr/share/info --mandir=/usr/share/man --disable-silent-rules --disable-dependency-tracking --with-libtool-sysroot=/mnt/home/skumar065c/rajkumar-workspace/rdkv/build-qemux86hyb/tmp/sysroots/qemux86hyb --disable-valgrind --disable-debug --disable-examples --disable-freetypetest --disable-examples --disable-x --disable-xvideo --disable-xshm --disable-oggtest --disable-gtk-doc --disable-cdparanoia --disable-gnome_vfs --disable-pango --disable-vorbistest --disable-freetypetest --disable-gdp --disable-adder --disable-app --disable-audiorate --disable-tcp --disable-videorate --enable-iso-codes --enable-subparse --enable-typefind --disable-audiotestsrc --disable-videotestsrc --enable-nls --disable-gnome_vfs --disable-ivorbis --disable-orc --disable-pango --disable-x --disable-xvideo
        make CFLAGS="-I/usr/include/gstreamer-1.0/"
        make install
    ;;
esac
}

echo "====================================================="
echo "********* List of rdkv-components are ***************"
echo "        1.gst-plugins-base                        "
echo "====================================================="
echo " usage:sh bulid_rdkv_devscript.sh UserName Component_Name"
echo "====================================================="

workspace_location="/build-qemux86hyb/source/"
mkdir -p $workspace_location
cd $workspace_location

execute_component $1 $2

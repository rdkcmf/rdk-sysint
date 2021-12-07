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

#BD-1004 - Removed licensed components
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
    "rdkbrowser")
        git clone https://$1@code.rdkcentral.com/r/components/generic/rdkbrowser rdkbrowser
        cd rdkbrowser
        export QT_LFLAGS_ODBC=-lodbc
        export OPENSSL_LIBS="-lssl -lcrypto"
        export OE_QMAKE_AR="i586-rdk-linux-ar"
        export OE_QMAKE_CC="i586-rdk-linux-gcc  -m32 -march=i586 -fno-omit-frame-pointer -fno-optimize-sibling-calls"
        export OE_QMAKE_CFLAGS="-O2 -pipe -feliminate-unused-debug-types -I=/usr/include/breakpad  ${CEFDBGFLAGS}"
        export OE_QMAKE_COMPILER="i586-rdk-linux-gcc  -m32 -march=i586 -fno-omit-frame-pointer -fno-optimize-sibling-calls"
        export OE_QMAKE_CXX="i586-rdk-linux-g++  -m32 -march=i586 -fno-omit-frame-pointer -fno-optimize-sibling-calls"
        export OE_QMAKE_CXXFLAGS="-O2 -pipe -feliminate-unused-debug-types -fvisibility-inlines-hidden -I=/usr/include/breakpad  ${CEFDBGFLAGS}"
        export OE_QMAKE_LDFLAGS="-Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed"
        export OE_QMAKE_LINK="i586-rdk-linux-g++  -m32 -march=i586 -fno-omit-frame-pointer -fno-optimize-sibling-calls"
        export OE_QMAKE_STRIP=echo
        export styles=mac fusion windows
        export QT_CFLAGS_GLIB="-pthread -I/mnt/home/skumar065c/rajkumar-workspace/AZ/build-qemux86hyb/tmp/sysroots/qemux86hyb/usr/include/glib-2.0"
        export QT_LIBS_GLIB="-lgthread-2.0 -pthread -lglib-2.0"
        export QMAKE_INCDIR_OPENGL_ES2=
        export QMAKE_LIBDIR_OPENGL_ES2=
        export QMAKE_LIBS_OPENGL_ES2="-lGLESv2"
        export QMAKE_INCDIR_LIBUDEV=
        export QMAKE_LIBS_LIBUDEV=-ludev
        export QMAKE_CFLAGS_XKBCOMMON=
        export QMAKE_LIBS_XKBCOMMON=-lxkbcommon
        export QMAKE_VERSION_XKBCOMMON=0.5.0
        export QMAKE_INCDIR_EGL=
        export QMAKE_LIBS_EGL=-lEGL
        export RDK_PROJECT_ROOT_PATH=/build-qemux86hyb/source

        sed -i 's/QT.gui.CONFIG = needs_qpa_plugin opengl/QT.gui.CONFIG = needs_qpa_plugin/1' /usr/lib/qt5/mkspecs/modules/qt_lib_gui.pri
        sed -i "19i include(/usr/lib/qt5/mkspecs/modules/qt_lib_gui.pri)" rdkbrowser.pro
        sed -i "20i include(/usr/lib/qt5/mkspecs/modules/qt_lib_gui.pri)" rdkbrowser.pro
        sed -i "21i include(/usr/lib/qt5/mkspecs/modules/qt_lib_widgets.pri)" rdkbrowser.pro
        sed -i "22i include(/usr/lib/qt5/mkspecs/modules/qt_lib_core.pri)" rdkbrowser.pro
        sed -i "23i include(/usr/lib/qt5/mkspecs/modules/qt_lib_3d.pri)" rdkbrowser.pro
        sed -i "24i include(/usr/lib/qt5/mkspecs/modules/qt_lib_3dquick.pri)" rdkbrowser.pro
        sed -i "25i include(/usr/lib/qt5/mkspecs/modules/qt_lib_bootstrap.pri)" rdkbrowser.pro
        sed -i "26i include(/usr/lib/qt5/mkspecs/modules/qt_lib_clucene.pri)" rdkbrowser.pro
        sed -i "27i include(/usr/lib/qt5/mkspecs/modules/qt_lib_concurrent.pri)" rdkbrowser.pro
        sed -i "28i include(/usr/lib/qt5/mkspecs/modules/qt_lib_declarative.pri)" rdkbrowser.pro
        sed -i "29i include(/usr/lib/qt5/mkspecs/modules/qt_lib_help.pri)" rdkbrowser.pro
        sed -i "30i include(/usr/lib/qt5/mkspecs/modules/qt_lib_location.pri)" rdkbrowser.pro
        sed -i "31i include(/usr/lib/qt5/mkspecs/modules/qt_lib_multimedia.pri)" rdkbrowser.pro
        sed -i "32i include(/usr/lib/qt5/mkspecs/modules/qt_lib_multimediawidgets.pri)" rdkbrowser.pro
        sed -i "33i include(/usr/lib/qt5/mkspecs/modules/qt_lib_opengl.pri)" rdkbrowser.pro
        sed -i "34i include(/usr/lib/qt5/mkspecs/modules/qt_lib_openglextensions.pri)" rdkbrowser.pro
        sed -i "35i include(/usr/lib/qt5/mkspecs/modules/qt_lib_platformsupport.pri)" rdkbrowser.pro
        sed -i "36i include(/usr/lib/qt5/mkspecs/modules/qt_lib_publishsubscribe.pri)" rdkbrowser.pro
        sed -i "37i include(/usr/lib/qt5/mkspecs/modules/qt_lib_qml.pri)" rdkbrowser.pro
        sed -i "38i include(/usr/lib/qt5/mkspecs/modules/qt_lib_qmldevtools.pri)" rdkbrowser.pro
        sed -i "39i include(/usr/lib/qt5/mkspecs/modules/qt_lib_qmltest.pri)" rdkbrowser.pro
        sed -i "40i include(/usr/lib/qt5/mkspecs/modules/qt_lib_qtmultimediaquicktools.pri)" rdkbrowser.pro
        sed -i "41i include(/usr/lib/qt5/mkspecs/modules/qt_lib_quick.pri)" rdkbrowser.pro
        sed -i "42i include(/usr/lib/qt5/mkspecs/modules/qt_lib_quickparticles.pri)" rdkbrowser.pro
        sed -i "43i include(/usr/lib/qt5/mkspecs/modules/qt_lib_script.pri)" rdkbrowser.pro
        sed -i "44i include(/usr/lib/qt5/mkspecs/modules/qt_lib_scripttools.pri)" rdkbrowser.pro
        sed -i "45i include(/usr/lib/qt5/mkspecs/modules/qt_lib_sensors.pri)" rdkbrowser.pro
        sed -i "46i include(/usr/lib/qt5/mkspecs/modules/qt_lib_serialport.pri)" rdkbrowser.pro
        sed -i "47i include(/usr/lib/qt5/mkspecs/modules/qt_lib_serviceframework.pri)" rdkbrowser.pro
        sed -i "48i include(/usr/lib/qt5/mkspecs/modules/qt_lib_sql.pri)" rdkbrowser.pro
        sed -i "49i include(/usr/lib/qt5/mkspecs/modules/qt_lib_svg.pri)" rdkbrowser.pro
        sed -i "50i include(/usr/lib/qt5/mkspecs/modules/qt_lib_systeminfo.pri)" rdkbrowser.pro
        sed -i "51i include(/usr/lib/qt5/mkspecs/modules/qt_lib_testlib.pri)" rdkbrowser.pro
        sed -i "52i include(/usr/lib/qt5/mkspecs/modules/qt_lib_uitools.pri)" rdkbrowser.pro
        sed -i "53i include(/usr/lib/qt5/mkspecs/modules/qt_lib_webkit.pri)" rdkbrowser.pro
        sed -i "56i include(/usr/lib/qt5/mkspecs/modules/qt_lib_webkitwidgets.pri)" rdkbrowser.pro
        sed -i "57i include(/usr/lib/qt5/mkspecs/modules/qt_lib_widgets.pri)" rdkbrowser.pro
        sed -i "58i include(/usr/lib/qt5/mkspecs/modules/qt_lib_xml.pri)" rdkbrowser.pro
        sed -i "59i include(/usr/lib/qt5/mkspecs/modules/qt_lib_xmlpatterns.pri)" rdkbrowser.pro
        sed -i "60i LIBS += -L/usr/lib -lQt5Gui -lQt5Core -lQt5Widgets" rdkbrowser.pro
        sed -i "61i INCLUDEPATH=/usr/include/qt5/QtGui /usr/include/qt5/QtGui/QtGuiDepends /usr/include/qt5 /usr/include/qt5/QtCore/ /usr/include/qt5/QtWidgets/ /usr/include/qt5/QtWebKitWidgets /usr/include/qt5/QtNetwork/ /usr/include/qt5/QtOpenGL" rdkbrowser.pro
        sed -i "62i LIBS += -L/usr/lib/ -lds-hal -ldshalcli -lds -L/usr/lib -ldirect -ldbus-1 -lIARMBus -L/usr/lib -lQt5WebKitWidgets -lxslt -lz -lm -lxml2 -ludev -lgio-2.0 -lgstapp-1.0 -lgstpbutils-1.0 -lgstvideo-1.0 -lgstaudio-1.0 -lgstbase-1.0 -lgsttag-1.0 -lgstreamer-1.0 -lgobject-2.0 -lglib-2.0 -lsqlite3 -lQt5Sql -lQt5OpenGL -lQt5WebKit -lQt5Widgets -lQt5Network -lQt5Gui -lQt5Core -lGLESv2 -lpthread" rdkbrowser.pro
        sed -i "63i DEFINES += QT_DISABLE_DEPRECATED_BEFORE=5" rdkbrowser.pro

        qmake -r -spec /usr/lib/qt5/mkspecs/linux-oe-g++/ /build-qemux86hyb/source/rdkbrowser/rdkbrowser.pro
        make
    ;;
    "gst-plugins-rdk")
        git clone https://$1@code.rdkcentral.com/r/components/generic/gst-plugins-rdk gst-plugins-rdk
        cd gst-plugins-rdk
        autoreconf -i
        ./configure --build=x86_64-linux --host=i586-rdk-linux --target=i586-rdk-linux --prefix=/usr --exec_prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin --libexecdir=/usr/lib/gst-plugins-rdk --datadir=/usr/share --sysconfdir=/etc --sharedstatedir=/com --localstatedir=/var --libdir=/usr/lib --includedir=/usr/include --oldincludedir=/usr/include --infodir=/usr/share/info --mandir=/usr/share/man --disable-silent-rules --disable-dependency-tracking --with-libtool --enable-gstreamer1=yes --enable-dtcpdec --enable-dtcpenc --enable-httpsink --enable-httpsrc --enable-rbifilter --enable-tee
        make CFLAGS="-O2 -pipe -g -feliminate-unused-debug-types -I=/usr/include/breakpad  -UENABLE_READ_DELAY -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include -pthread -I/usr/include/gstreamer-1.0 -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include" LDFLAGS="-Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed"
        make install
    ;;
    "gst-plugins-playersinkbin-emulator")
        git clone https://$1@code.rdkcentral.com/r/devices/intel-x86-pc/rdkemulator/gst-plugins-rdk/playersinkbin gst-plugins-playersinkbin-emulator
        cd gst-plugins-playersinkbin-emulator
        autoreconf -i
        ./configure --build=x86_64-linux --host=i586-rdk-linux --target=i586-rdk-linux --prefix=/usr --exec_prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin --libexecdir=/usr/lib/gst-plugins-playersinkbin-emulator --datadir=/usr/share --sysconfdir=/etc --sharedstatedir=/com --localstatedir=/var --libdir=/usr/lib --includedir=/usr/include --oldincludedir=/usr/include --infodir=/usr/share/info --mandir=/usr/share/man --disable-silent-rules --disable-dependency-tracking --with-libtool-sysroot --enable-gstreamer1=yes
        make CFLAGS="-O2 -pipe -g -feliminate-unused-debug-types -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include -pthread -I/usr/include/gstreamer-1.0 -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include -O2 -pipe -g -feliminate-unused-debug-types -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include -pthread -I/usr/include/gstreamer-1.0 -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include" LDFLAGS="-Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed -Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed"
        make install
    ;;
    "gstqamtunersrc")
        git clone https://$1@code.rdkcentral.com/r/devices/intel-x86-pc/rdkemulator/gst-plugins-rdk/qamtunersrc gstqamtunersrc
        cd gstqamtunersrc
        autoreconf -i
        ./configure --build=x86_64-linux --host=i586-rdk-linux --target=i586-rdk-linux --prefix=/usr --exec_prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin --libexecdir=/usr/lib/gstqamtunersrc --datadir=/usr/share --sysconfdir=/etc --sharedstatedir=/com --localstatedir=/var --libdir=/usr/lib --includedir=/usr/include --oldincludedir=/usr/include --infodir=/usr/share/info --mandir=/usr/share/man --disable-silent-rules --disable-dependency-tracking --with-libtool-sysroot --enable-gstreamer1=yes
        make CFLAGS="-O2 -pipe -g -feliminate-unused-debug-types  -I/usr/include/hdhomerun -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include -pthread -I/usr/include/gstreamer-1.0 -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include -O2 -pipe -g -feliminate-unused-debug-types  -I/usr/include/hdhomerun -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include -pthread -I/usr/include/gstreamer-1.0 -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include" LDFLAGS="-Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed -Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed -L/usr/lib/"
        make install
    ;;
esac
}

echo "====================================================="
echo "********* List of rdkv-components are ***************"
echo "        1.rdkbrowser                              "
echo "        2.gst-plugins-base                        "
echo "        3.gst-plugins-rdk                         "
echo "        4.gstqamtunersrc 				"
echo "        5.gst-plugins-playersinkbin-emulator      "
echo "====================================================="
echo " usage:sh bulid_rdkv_devscript.sh UserName Component_Name"
echo "====================================================="

workspace_location="/build-qemux86hyb/source/"
mkdir -p $workspace_location
cd $workspace_location

execute_component $1 $2

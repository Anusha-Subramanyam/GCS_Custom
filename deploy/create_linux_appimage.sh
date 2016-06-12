#!/bin/bash -x

set +e

if [[ $# -eq 0 ]]; then
	echo 'create_linux_appimage.sh QGC_SRC_DIR QGC_RELEASE_DIR'
	exit 1
fi

QGC_SRC=$1
if [ ! -f ${QGC_SRC}/qgroundcontrol.pro ]; then
	echo 'please specify path to qgroundcontrol source as the 1st argument'
	exit 1
fi

QGC_RELEASE_DIR=$2
if [ ! -f ${QGC_RELEASE_DIR}/qgroundcontrol ]; then
	echo 'please specify path to qgroundcontrol release as the 2nd argument'
	exit 1
fi

OUTPUT_DIR=${3-`pwd`}
echo "Output directory:" ${OUTPUT_DIR}

# Generate AppImage using the binaries currently provided by the project.
# These require at least GLIBC 2.14, which older distributions might not have. 
# On the other hand, 2.14 is not that recent so maybe we can just live with it.

APP=QGroundControl

TMPDIR=`mktemp -d`
APPDIR=${TMPDIR}/$APP".AppDir"
mkdir -p ${APPDIR}

cd ${TMPDIR}
wget -c --quiet http://ftp.us.debian.org/debian/pool/main/u/udev/udev_175-7.2_amd64.deb
wget -c --quiet http://ftp.us.debian.org/debian/pool/main/e/espeak/espeak_1.46.02-2_amd64.deb
wget -c --quiet http://ftp.us.debian.org/debian/pool/main/libs/libsdl1.2/libsdl1.2debian_1.2.15-5_amd64.deb

cd ${APPDIR}
find ../ -name *.deb -exec dpkg -x {} . \;

# copy libdirectfb-1.2.so.9
cd ${TMPDIR}
wget -c --quiet http://ftp.us.debian.org/debian/pool/main/d/directfb/libdirectfb-1.2-9_1.2.10.0-5.1_amd64.deb
mkdir libdirectfb
dpkg -x libdirectfb-1.2-9_1.2.10.0-5.1_amd64.deb libdirectfb
cp -L libdirectfb/usr/lib/x86_64-linux-gnu/libdirectfb-1.2.so.9 ${APPDIR}/usr/lib/x86_64-linux-gnu/

# copy QGroundControl release into appimage
cp -r ${QGC_RELEASE_DIR}/* ${APPDIR}/
rm -rf ${APPDIR}/package
mv ${APPDIR}/qgroundcontrol-start.sh ${APPDIR}/AppRun

# copy icon
cp ${QGC_SRC}/resources/icons/qgroundcontrol.png ${APPDIR}/

# copy linux desktop entry
cp ${QGC_SRC}/deploy/qgroundcontrol.desktop ${APPDIR}/

# Add desktop integration - WORK IN PROGRESS
cd ${APPDIR}
mv qgroundcontrol.desktop AppRun.desktop
XAPP=QGroundControl
wget -O ${APPDIR}/usr/bin/AppRun.wrapper https://raw.githubusercontent.com/probonopd/AppImageKit/master/desktopintegration
chmod a+x ${APPDIR}/usr/bin/AppRun.wrapper
sed -i -e "s|Exec=AppRun|Exec=AppRun.wrapper|g" AppRun.desktop

VERSION=$(strings ${APPDIR}/qgroundcontrol | grep '^v[0-9*]\.[0-9*].[0-9*]' | head -n 1)
echo QGC Version: ${VERSION}

# Go out of AppImage
cd ${TMPDIR}
wget -c --quiet "https://github.com/probonopd/AppImageKit/releases/download/5/AppImageAssistant" # (64-bit)
chmod a+x ./AppImageAssistant

# delete previous AppImage if necessary
rm ${TMPDIR}/$APP".AppImage" || true

./AppImageAssistant ./$APP.AppDir/ ${TMPDIR}/$APP".AppImage"

cp ${TMPDIR}/$APP".AppImage" ${OUTPUT_DIR}/$APP".AppImage"


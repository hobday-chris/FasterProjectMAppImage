#!/bin/sh -e
# BuildFPMAppImage.sh

# Install needed dolphin dependencies
sudo apt install -y cmake pkg-config git wget libao-dev libasound2-dev libavcodec-dev libavformat-dev libbluetooth-dev libenet-dev libgtk2.0-dev liblzo2-dev libminiupnpc-dev libopenal-dev libpulse-dev libreadline-dev libsfml-dev libsoil-dev libsoundtouch-dev libswscale-dev libusb-1.0-0-dev libwxbase3.0-dev libwxgtk3.0-dev libxext-dev libxrandr-dev portaudio19-dev zlib1g-dev libudev-dev libevdev-dev libmbedtls-dev libcurl4-openssl-dev libegl1-mesa-dev libpng-dev qtbase5-private-dev libxxf86vm-dev libxmu-dev libxi-dev 

# --- Config links
FPPVERSION="2.25" # Name of FPP version, used in folder name
# CONFIGNAME="fppconfig"
# CONFIGLINK="https://github.com/Birdthulu/FPM-Installer/raw/master/config/$FPPVERSION-$CONFIGNAME.tar.gz"
GITCLONELINK="https://github.com/Birdthulu/Ishiiruka"
COMMITHASH="0311660c433eb04755c93160bdfe1ea516364c68"
# ---

# --- Delete FasterProjectPlus folders
rm -rf FasterProjectPlus*/
echo "Deleted all FPP folders!"
# ---

# --- Set FOLDERNAME based on FPP version
FOLDERNAME="FasterProjectPlus-${FPPVERSION}"

# --- Make folder, enter and download then extract needed files
# echo ""
mkdir "$FOLDERNAME" && cd "$FOLDERNAME"
# echo "Downloading config files..."
# curl -LO# $CONFIGLINK
# echo "Extracting config files..."
# tar -xzf "$FPPVERSION-$CONFIGNAME.tar.gz" --checkpoint-action='exec=printf "%d/410 records extracted.\r" $TAR_CHECKPOINT' --totals
# rm "$FPPVERSION-$CONFIGNAME.tar.gz"
# echo ""
echo "Downloading tarball..."
curl -LO# "$GITCLONELINK/archive/$COMMITHASH.tar.gz"
echo "Extracting tarball..."
tar -xzf "$COMMITHASH.tar.gz" --checkpoint-action='exec=printf "%d/12130 records extracted.\r" $TAR_CHECKPOINT' --totals
rm "$COMMITHASH.tar.gz"
echo "" #spacing
mv "Ishiiruka-$COMMITHASH" Ishiiruka
cd Ishiiruka
# ---

# --- Patch tarball to display correct hash to other netplay clients
echo "Patching tarball..."
sed -i "s|\${GIT_EXECUTABLE} rev-parse HEAD|echo ${COMMITHASH}|g" CMakeLists.txt  # --set scm_rev_str everywhere to actual commit hash when downloaded
sed -i "s|\${GIT_EXECUTABLE} describe --always --long --dirty|echo FM v$FPPVERSION|g" CMakeLists.txt # ensures compatibility w/ netplay
sed -i "s|\${GIT_EXECUTABLE} rev-parse --abbrev-ref HEAD|echo HEAD|g" CMakeLists.txt
# ---

# --- Patch DiscExtractor.h
echo "Patching DiscExtractor.h"
sed -i "s|#include <optional>|#include <optional>\n#include <string>|g" Source/Core/DiscIO/DiscExtractor.h
# ---

# --- Patch wxWidgets3 for Ubuntu 20.04
echo "Patching wxWidgets3 for Ubuntu 20.04 based distros"
sed -i "s| OR NOT X11_Xinerama_FOUND||g" Externals/wxWidgets3/CMakeLists.txt
sed -i "s|needs Xinerama and|needs|g" Externals/wxWidgets3/CMakeLists.txt
sed -i "s|\t\t\${X11_Xinerama_LIB}||g" Externals/wxWidgets3/CMakeLists.txt
# ---

# --- Move wx files into source
cp Externals/wxWidgets3/include/wx Source/Core/ -r
cp Externals/wxWidgets3/wx/* Source/Core/wx/
# ---

# --- Move necessary config files into the build folder
echo "Adding FPP config files..."
mkdir build && cd build
mv ../../Binaries .
cp ../Data/ishiiruka.png Binaries/
# ---

# --- Cmake and compile
echo "Cmaking..."
cmake .. -DLINUX_LOCAL_DEV=true -DCMAKE_INSTALL_PREFIX=/usr
echo "Compiling..."
make -j$(nproc) # Make with all cores
# ---

# --- Create .desktop file
touch Binaries/ishiiruka.desktop
echo "[Desktop Entry]
Type=Application
GenericName=Wii/GameCube Emulator
Comment=Ishiiruka fork for SSBPM
Exec=ishiiruka
Categories=Emulator;Game;
Icon=ishiiruka
Keywords=ProjectM;Project M;ProjectPlus;Project Plus;Project+
Name=Faster Project M" >> Binaries/ishiiruka.desktop
cp Binaries/ishiiruka.desktop ../Data/ishiiruka.desktop
# ---

# --- Delete existing AppDir, make a new one and Make install into it
rm -rf AppDir/
mkdir AppDir
make install DESTDIR=AppDir
# ---

APPIMAGE_STRING="Faster_Project_M-x86_64.AppImage"

LINUXDEPLOY_PATH="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous"
LINUXDEPLOY_FILE="linuxdeploy-x86_64.AppImage"
LINUXDEPLOY_URL="${LINUXDEPLOY_PATH}/${LINUXDEPLOY_FILE}"

APPIMAGETOOL_PATH="https://github.com/AppImage/AppImageKit/releases/download/continuous"
APPIMAGETOOL_FILE="appimagetool-x86_64.AppImage"
APPIMAGETOOL_URL="${APPIMAGETOOL_PATH}/${APPIMAGETOOL_FILE}"

APPDIR_BIN="AppDir/usr/bin"

# --- Download linuxdeploy and appimagetool if not already there
if [ ! -e linuxdeploy ]; then
	wget ${LINUXDEPLOY_URL} -O linuxdeploy
	chmod +x linuxdeploy
fi
if [ ! -e appimagetool ]; then
	wget ${APPIMAGETOOL_URL} -O appimagetool
	chmod +x appimagetool
fi
# ---

# --- Run linuxdepoly on AppDir
./linuxdeploy --appdir AppDir
# ---

# --- Remove autogenerated AppDir/AppRun
rm -f AppDir/AppRun
# ---

# --- Create new AppRun which sets relative library path before calling binary and set it executable
cat > AppDir/AppRun <<\EOF
#!/bin/bash
APPDIR="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${APPDIR}/usr/lib:${LD_LIBRARY_PATH}"
${APPDIR}/usr/bin/ishiiruka
EOF
chmod +x AppDir/AppRun
# ---

# --- Copy needed files/folders
cp Binaries/license.txt ${APPDIR_BIN}
cp Binaries/Changelog.txt ${APPDIR_BIN}
cp Binaries/traversal_server ${APPDIR_BIN}
# ---

# --- Remove appimage if it exists already
rm -f ${APPIMAGE_STRING}
# ---

# --- Make appimage
./appimagetool AppDir
# ---
#!/bin/bash
trap "exit" INT

exitMsg() {
	echo
	echo $1
	echo "Exiting..."
	exit 1
}

if [ whoami = root ]; then
	exitMsg "Do not run this script with root privileges!"
fi

echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
echo '!! This Script is not finished !!'
echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
echo
echo 'If you really want to run this, answer the next question with "Yes." (excluding the quotes, including the dot, case matching.)'
echo
read -p 'Are you ready to break your PC? - ' sure
if [ $sure != 'Yes!' ]; then
	exitMsg
fi

###################
# What do I want inside this script:
# Multiple distros
# Multiple sound systems
# proper checks
# proper error messages
# 	so I know what's up
# 	so the user knows what's up
# ask questions
#
# How do I want to approach this:
# * add arch-pipewire guide
# * add native jack too.
# * do proper checks and error messages.
# * Multiple distros
# * Write prompts and stuff

# Set variables
# This is temporary
STEAMLIBRARY="/mnt/HDD/Games/Steam"
game="$STEAMLIBRARY/steamapps/common/Rocksmith2014"
PROTON="/home/john/.steam/steam/steamapps/common/Proton 9.0 (Beta)/files"
WORKINGDIR=~/.linux-rocksmith
wineasiover="1.2.0"
rsasiover="0.7.4"
sound=pipewire
dist=arch

# Install necessary
case $sound in
	pipewire)
		packages="wine-staging pipewire-alsa pipewire-pulse pipewire-jack lib32-pipewire-jack qpwgraph realtime-privileges pavucontrol base-devel"
		;;
	native)
		packages="jack2 lib32-jack2 realtime-privileges qjackctl base-devel"
		;;
	*)
		exitMsg "Could not determine your sound setup!"
esac
sudo pacman -S $packages
sudo groupadd audio
sudo groupadd realtime
sudo usermod -aG audio $USER
sudo usermod -aG realtime $USER

# Create working directory
mkdir -p $WORKINGDIR

# Install RS_ASIO
cd $WORKINGDIR
rsasiover=$(get-latest https://api.github.com/repos/mdias/rs_asio/releases/latest)
wget https://github.com/mdias/rs_asio/releases/download/v$rsasiover/release-$rsasiover.zip
unzip release-$rsasiover.zip -d "$game" -x RS_ASIO.ini
wget https://raw.githubusercontent.com/theNizo/linux_rocksmith/main/RS_ASIO.ini -O "$game/RS_ASIO.ini"

# Wineasio
# Download
cd $WORKINGDIR
wineasiover=$(get-latest https://api.github.com/repos/wineasio/wineasio/releases/latest)
wget https://github.com/wineasio/wineasio/releases/download/v$wineasiover/wineasio-$wineasiover.tar.gz -O wineasio.tar.gz
tar -xf wineasio-$wineasiover.tar.gz
cd wineasio-$wineasiover
# compile
rm -rf build32
rm -rf build64
make 32
make 64
#Install
sudo cp build32/wineasio32.dll /usr/lib32/wine/i386-windows/wineasio32.dll
sudo cp build32/wineasio32.dll.so /usr/lib32/wine/i386-unix/wineasio32.dll.so
sudo cp build64/wineasio64.dll /usr/lib/wine/x86_64-windows/wineasio64.dll
sudo cp build64/wineasio64.dll.so /usr/lib/wine/x86_64-unix/wineasio64.dll.so
cp /usr/lib32/wine/i386-unix/wineasio32.dll.so "$PROTON/lib/wine/i386-unix/wineasio32.dll.so"
cp /usr/lib32/wine/i386-windows/wineasio32.dll "$PROTON/lib/wine/i386-windows/wineasio32.dll"
cp /usr/lib/wine/x86_64-unix/wineasio64.dll.so "$PROTON/lib64/wine/x86_64-unix/wineasio64.dll.so"
cp /usr/lib/wine/x86_64-windows/wineasio64.dll "$PROTON/lib64/wine/x86_64-windows/wineasio64.dll"

# Prepare prefix
compat=$STEAMLIBRARY/steamapps/compatdata/221680
rm $compat.bak
mv $compat $compat.bak
echo "Re-generating prefix now by launching the game.
You can close it again, when you see the window appear"
read -p "Press enter to continue"
xdg-open steam://rungameid/221680 #run game

# Patch prefix
echo
echo
echo "Please confirm that you have closed the game."
read -p "Press enter to continue"
env WINEPREFIX=$pfx ./wineasio-register
echo "all done"
exit 0

#!/bin/bash
trap "exit" INT

if [ whoami = root ]; then
	exitMsg "Do not run this script with root privileges!"
fi

exitMsg() {
	echo
	echo $1
	echo "Exiting..."
	exit 1
}

get-latest() {
	var=$(curl $1 | jq -r ".tag_name")
	echo "${var:1}"
}

ldd-negative() {
	echo
	echo
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo "!! Building wineasio $1 bit successfull, but not !!"
	echo "!! all dependencies for this file can be found.  !!"
	echo "!! You will have to fix this after the setup     !!"
	echo "!! completes. you can run \"ldd\" to see which   !!"
	echo "!! dependency causes problems.                   !!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo
	echo
}

echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
echo '!! THIS SCRIPT IS NOT FINISHED !!'
echo '!!    AND IT IS NOT TESTED     !!'
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
# * Write prompts and stuff
# * Multiple distros

# Set variables
# This is temporary
STEAMLIBRARY="/mnt/HDD/Games/Steam"
game="$STEAMLIBRARY/steamapps/common/Rocksmith2014"
compat="$STEAMLIBRARY/steamapps/compatdata/221680"
PROTON="/home/john/.steam/steam/steamapps/common/Proton 9.0 (Beta)/files"
WORKINGDIR=~/.linux-rocksmith
wineasiover="1.2.0"
rsasiover="0.7.4"
sound=pipewire
dist=arch



error=false


# Prerequisites
# Grouped up all download processes as close as possible.
mkdir -p $WORKINGDIR
cd $WORKINGDIR

rsasiover=$(get-latest https://api.github.com/repos/mdias/rs_asio/releases/latest)
echo "Downloading RS_ASIO version $rsasiover"
wget https://github.com/mdias/rs_asio/releases/download/v$rsasiover/release-$rsasiover.zip
if [ -e release-$rsasiover.zip ]; then
	echo "Successfully downloaded RS_ASIO."
else
	exitMsg "Could not download RS_ASIO."
fi

wineasiover=$(get-latest https://api.github.com/repos/wineasio/wineasio/releases/latest)
echo "Downloading wineasio version $wineasiover"
wget https://github.com/wineasio/wineasio/releases/download/v$wineasiover/wineasio-$wineasiover.tar.gz
if ! [ -e wineasio-$wineasiover.tar.gz ]; then
	echo "Successfully downloaded wineasio."
else
	exitMsg "Could not download wineasio."
fi
###################
# Install necessary
###################
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
for pkg in $packages; do
	if ! pacman -Q $pkg; then
		echo "Package $pkg has not been installed."
		error=true
	fi
done
if [ error = true ]; then
	exitMsg "Some packages have not been installed successfully."
fi

sudo groupadd audio
sudo groupadd realtime
sudo usermod -aG audio $USER
sudo usermod -aG realtime $USER


###################
# Install RS_ASIO #
###################
unzip release-$rsasiover.zip -d "$game" -x RS_ASIO.ini
wget https://raw.githubusercontent.com/theNizo/linux_rocksmith/main/RS_ASIO.ini -O "$game/RS_ASIO.ini"
for $file in "$game/avrt.dll" "$game/RS_ASIO.dll" "$game/RS_ASIO.ini"; do
	if ! [ -e "$file" ]; then
	exitMsg "RS_ASIO was not installed properly."
fi
echo "Successfully installed RS_ASIO."

############
# Wineasio #
############

# Download
tar -xf wineasio-$wineasiover.tar.gz
cd wineasio-$wineasiover

# compile
rm -rf build32
rm -rf build64
make 32 > "wineasio-build-32.txt"
make 64 > "wineasio-build-64.txt"

for $file in build32/wineasio32.dll build32/wineasio32.dll.so build64/wineasio64.dll build64/wineasio64.dll.so; do
	if ! [ -e $file ]; then
		exitMsg "Wineasio could not be compiled successfully. see the log files\n$(pwd)/wineasio-build-32.txt\n$(pwd)/wineasio-build-64.txt"
	fi
done

# Checks if dll.so dependencies are fullfilled
if [ $(ldd build32/wineasio32.dll.so | grep "not found") ]; then
	ldd-negative 32
fi
if [ $(ldd build64/wineasio64.dll.so | grep "not found") ]; then
	ldd-negative 64
fi

#Install
sudo cp build32/wineasio32.dll -v /usr/lib32/wine/i386-windows/wineasio32.dll
sudo cp build32/wineasio32.dll.so -v /usr/lib32/wine/i386-unix/wineasio32.dll.so
sudo cp build64/wineasio64.dll -v /usr/lib/wine/x86_64-windows/wineasio64.dll
sudo cp build64/wineasio64.dll.so -v /usr/lib/wine/x86_64-unix/wineasio64.dll.so
cp /usr/lib32/wine/i386-unix/wineasio32.dll.so -v "$PROTON/lib/wine/i386-unix/wineasio32.dll.so"
cp /usr/lib32/wine/i386-windows/wineasio32.dll -v "$PROTON/lib/wine/i386-windows/wineasio32.dll"
cp /usr/lib/wine/x86_64-unix/wineasio64.dll.so -v "$PROTON/lib64/wine/x86_64-unix/wineasio64.dll.so"
cp /usr/lib/wine/x86_64-windows/wineasio64.dll -v "$PROTON/lib64/wine/x86_64-windows/wineasio64.dll"

echo "Installed wineasio."

##########
# prefix #
##########

# prepare
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
echo "all done. Please log out, read stuff and other things I forgot to mention"
exit 0

#!/bin/bash
trap "echo; exit" INT

if [ "$(id -u)" -eq 0 ]; then
	echo "Do not run this script with root privileges!"
	exit 1
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

exitMsg() {
	echo
	echo "$1"
	echo "Exiting..."
	exit 1
}

get-latest() {
	var=$(curl -s "$1" | grep tag_name | sed -e 's/.*"v//g' -e 's/",//g')
	if [ -z "$var" ]; then
		exitMsg "Could not determine version from $1"
	fi
	echo "$var"
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

header() {
	clear
	echo -e "linux_rocksmith script version 0.0.1\n\n$1\n"
}

ask_settings() {
	WORKINGDIR=~/.linux-rocksmith

	# STEAMLIBRARY
	if [ -f "$HOME/.steam/steam/steamapps/common/Rocksmith2014/Rocksmith2014.exe" ]; then
		echo "Game installation found in the default Steam Library. Using this."
		echo
		game=$HOME/.steam/steam/steamapps/common/Rocksmith2014
	else
		header "Setup: Game Root folder"
		echo "Please specify the root folder of the game's"
		echo "installation. Should contain 'Rocksmith.exe'"
		echo
		read -rp "Rocksmith install path: " game
		while [ ! -f "$game/Rocksmith2014.exe" ]; do
			echo
			echo "Could not find Rocksmith2014.exe inside this folder."
			echo "Please try again."
			read -rp "Rocksmith install path: " game
		done
	fi
	check_game_var

	# PROTON
	header "Settings: Select Proton"
	echo "Please specify the root of your Proton installation"
	echo "that you want to use. It needs to be Proton,"
	echo "otherwise the game can't detect Steam"
	echo
	read -rp "Proton: " runner
	while ! [ -f "$runner/dist/bin/wine" ] && ! [ -f "$runner/files/bin/wine" ]; do
		echo
		echo "This doesn't seem to be a Proton installation path, please try again."
		read -rp "Proton: " runner
	done

	# adjust path accordingly, if needed.
	# PROTON, so I can copy-paste commands from the guides
	if [ -f "$runner/dist/bin/wine" ]; then
		PROTON="$runner/dist"
	elif [ -f "$runner/files/bin/wine" ]; then
		PROTON="$runner/files"
	else
		echo "There's something wrong with the Proton path recognition."
		exitMsg "Please open an issue on the repo."
	fi

	# Sound system
	header "Settings: JACK"
	echo "Choose JACK variant by number"
	soundlist=("pipewire-JACK" "native JACK")
	select ans in "${soundlist[@]}"; do
		case $ans in
			"${soundlist[0]}")
				echo "Setting sound to pipewire-jack"
				sound=pipewire
				break
				;;
			"${soundlist[1]}")
				echo "Setting sound to native JACK"
				sound=native
				break
				;;
			*)
				echo "Invalid input."
		esac
	done
}

readExit() {
	echo
	echo "$1"
	echo
	echo "Usage: ./script.sh [working dir] [Rocksmith root folder] [Proton path] [jack version.]"
	exit 1
}
read_settings() {
	WORKINGDIR="$1"
	game="$2"
	PROTON="$3"
	sound="$4"
	runner=$(realpath "$PROTON/..") # so the preview works
	
	echo "$game"
	echo "$runner"
	echo "$sound"

	if ! [ -f "$game/Rocksmith2014.exe" ]; then
		readExit "Rocksmith path incorrect"
	fi
	check_game_var

	echo "$PROTON/../proton"
	if ! [ -f "$PROTON/../proton" ]; then 
		readExit "Proton path incorrect 1"
	fi
	if ! [ -f "$PROTON/bin/wine" ]; then
		readExit "Proton path incorrect 2"
	fi

	if ! [ "$sound" == "pipewire" ] && ! [ "$sound" == "native" ]; then
		readExit "$sound is not a valid jack option"
	fi
}

check_game_var() {
	# Considering every possible situation, symlinks will break *something*. Just don't.
	rspath=$(realpath "$game")
	if [ "$rspath/" != "$game" ]; then 
		exitMsg "Path to game's root folder should not include symlinks."
	fi
	if ! [ -d "$game/../../compatdata" ]; then
		exitMsg "The game's folder does not seem to be inside a Steam Library folder..."
	fi
	prefix=$(realpath "$game/../../compatdata/221680")
	STEAMLIBRARY="$game/../.."
}

select_guide() {
	case $sound in
		"pipewire")
			echo "https://github.com/theNizo/linux_rocksmith/blob/main/guides/setup/arch-pipewire.md"
			;;
		"native")
			echo "https://github.com/theNizo/linux_rocksmith/blob/main/guides/setup/arch-native.md"
			;;
		*)
			echo "Something went wrong finding the correct guide."
	esac
}

header
echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
echo '!! THIS SCRIPT IS NOT FINISHED !!'
echo '!!    AND IT IS NOT TESTED     !!'
echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
echo
echo 'If you really want to run this, answer the next question with "Yes." (excluding the quotes, including the dot, case matching.)'
echo
read -rp 'Are you ready to break your PC? - ' sure
if [ "$sure" != 'Yes.' ]; then
	exitMsg
fi

################
# Actual start #
################

if [ $# -eq 0 ]; then
	ask_settings
else
	read_settings "$1" "$2" "$3" "$4"
fi
# Overview
header "Settings: Overview"
echo "Working directory:     $WORKINGDIR"
echo "Game install location: $game"
echo "Proton Location:       $runner"
echo "JACK variant:          $sound"
echo
echo "The setup with this configuration can be run again with the following command:"
echo './setup-linux-rocksmith.sh "'"$WORKINGDIR"'" "'"$game"'" "'"$PROTON"'" '"$sound"
echo

answer=false
while [ "$answer" = false ]; do
	read -rp "Do you want to continue? [y/n] " ans
	case $ans in
        [Yy] ) break;;
        [Nn] ) exit;;
        * ) echo "Invalid answer.";;
    esac
done

#echo "starting the process in "
#echo "5"
#sleep 1
#echo "4"
#sleep 1
#echo "3"
#sleep 1
#echo "2"
#sleep 1
#echo "1"
#sleep 1
#echo "Starting install."

#################
# Prerequisites #
#################

# Grouped up all download processes as close as possible.
error=false
mkdir -p "$WORKINGDIR"
cd "$WORKINGDIR" || exit

rsasiover=$(get-latest https://api.github.com/repos/mdias/rs_asio/releases/latest)
echo "Downloading RS_ASIO version $rsasiover"
wget "https://github.com/mdias/rs_asio/releases/download/v$rsasiover/release-$rsasiover.zip" 2> /dev/null
if [ -e "release-$rsasiover.zip" ]; then
	echo "Successfully downloaded RS_ASIO."
else
	exitMsg "Could not download RS_ASIO."
fi

wineasiover=$(get-latest https://api.github.com/repos/wineasio/wineasio/releases/latest)
echo "Downloading wineasio version $wineasiover"
wget "https://github.com/wineasio/wineasio/releases/download/v$wineasiover/wineasio-$wineasiover.tar.gz" 2> /dev/null
if [ -e  "wineasio-$wineasiover.tar.gz" ]; then
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
		packages="wine-staging jack2 lib32-jack2 realtime-privileges qjackctl base-devel"
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
if [ $error = true ]; then
	exitMsg "Some packages have not been installed successfully."
fi

sudo groupadd audio
sudo groupadd realtime
sudo usermod -aG audio $USER
sudo usermod -aG realtime $USER


###################
# Install RS_ASIO #
###################
unzip "release-$rsasiover.zip" -d "$game" -x RS_ASIO.ini
wget https://raw.githubusercontent.com/theNizo/linux_rocksmith/main/RS_ASIO.ini -O "$game/RS_ASIO.ini" 2> /dev/null
cd "$game" || exit
for file in avrt.dll RS_ASIO.dll RS_ASIO.ini; do
	if ! [ -e "$file" ]; then
		exitMsg "RS_ASIO was not installed properly."
	fi
done
echo "Successfully installed RS_ASIO."
cd $WORKINGDIR || exit

############
# Wineasio #
############

# Download
echo "Building wineasio."
tar -xf "wineasio-$wineasiover.tar.gz"
cd wineasio-$wineasiover

# compile
rm -rf build32
rm -rf build64
make 32 > /dev/null
make 64 > /dev/null

for file in build32/wineasio32.dll build32/wineasio32.dll.so build64/wineasio64.dll build64/wineasio64.dll.so; do
	if ! [ -e $file ]; then
		exitMsg "Wineasio could not be compiled successfully."
	fi
done

# Checks if dll.so dependencies are fullfilled
if [ "$(ldd build32/wineasio32.dll.so | grep 'not found')" ]; then
	ldd-negative 32
fi
if [ "$(ldd build64/wineasio64.dll.so | grep 'not found')" ]; then
	ldd-negative 64
fi
echo "Built wineasio, installing..."

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
rm -rf "$prefix.bak"
mv "$prefix" "$prefix.bak"
echo
echo "====================================================="
echo "Re-generating prefix now by launching the game.
You can close it again, when you see the window appear"
echo 'An error saying "No audio output is detected. [...]" should appear.'
echo "====================================================="
echo
read -rp "Press enter to continue"
#xdg-open steam://rungameid/221680 #run game

# Patch prefix
echo 
echo
echo "Please confirm that you have closed the game."
read -rp "Press enter to continue"
env WINEPREFIX="$prefix/pfx" ./wineasio-register
echo
echo
echo "============================================
The game is now set up for the most part.
Please reboot your PC. (Logging out and back in might work too.)
Then follow these two sections from the guides:
* Set up JACK
* Starting the game
"
select_guide
echo "
These require steps that can only be done manually.

If you require further assistance, feel free to open an issue.
Since this script gives you limited knowledge about what happened,
please follow the guide below and list in your issue at which
step you fail.

https://github.com/theNizo/linux_rocksmith/blob/main/guides/troubleshoot-no-sound.md
============================================"
exit 0


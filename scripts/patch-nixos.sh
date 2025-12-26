#!/usr/bin/env bash

set -e

# show usage
if [[ $# -gt 0 && $1 = "--help" ]]; then
	echo -e "
Usage: ./patch-nixos-sh [ OPTIONS ]

-s, --steampath=    The Steam Library where Rocksmith is installed to. usually \$USER/.steam/steam
-w, --wineprefix=   The prefix for rocksmith
-r, --rsasiover=    Version of RS_ASIO you want to use
-p, --protonpath=   Location of the Proton version you want to use
-P, --protontype=   \"files\" or \"dist\" - which one your chosen Proton version uses
-C, --cdlc          Patch the game for use with CDLC too
-M, --mods          Run Lovrom8's Mod Installer
"
	exit 0
fi

######################### VARS ###############################
USER=$(whoami)

# Constants (these shouldn't change!)
WINEASIOPATH="/lib/wine"
WINEASIO32PATH="/lib32/wine"
WINEASIODLLS=(
	"/i386-unix/wineasio32.dll.so"
	"/i386-windows/wineasio32.dll"
	"/x86_64-unix/wineasio64.dll.so"
	"/x86_64-windows/wineasio64.dll"
)
LAUNCH_OPTIONS="LD_PRELOAD=/usr/lib32/libjack.so PIPEWIRE_LATENCY=256/48000 %command%"
LAUNCH_OPTIONS="LD_PRELOAD=/usr/lib32/librsshim.so:/usr/lib32/libjack.so PIPEWIRE_LATENCY=256/48000 %command%"
CDLC_INSTALLER="RS2014-CDLC-Installer.exe"
MODS_INSTALLER="RS2014-Mod-Installer.exe"

# Defaults
STEAMPATH="/home/${USER}/.steam/steam"
WINEPREFIX="${STEAMPATH}/steamapps/compatdata/221680/pfx/"
RSASIOVER="0.7.4"
PROTONVER="Proton 10.0"
FILES_OR_DIST="files"
PROTONPATH="${STEAMPATH}/steamapps/common/${PROTONVER}"
WINE="${PROTONPATH}/${FILES_OR_DIST}/bin/wine"
WINE64="${PROTONPATH}/${FILES_OR_DIST}/bin/wine64"
INSTALL_CDLC=false
INSTALL_MODS=false
PROTONPATH_SET=false
RSASIOVER_SET=false

print_color() {
	local COLOR=$1
	local NC='\033[0m'
	echo -e "${COLOR}$2${NC}"
}

print_blue() {
	local BLUE='\033[0;34m'
	print_color $BLUE "$1"
}

print_green() {
	local GREEN='\033[0;32m'
	print_color $GREEN "$1"
}

print_red() {
	local RED='\033[0;31m'
	print_color $RED "$1"
}

print_orange() {
	local ORANGE='\033[38;5;214m'
	print_color $ORANGE "$1"
}

validate_proton_input() {
	if [[ -z $1 || $1 =~ ^[0-2]$ ]]; then
		return 0
	else
		return 1
	fi
}

choose_proton() {
	if [ "$PROTONPATH_SET" = true ]; then
		return
	fi

	echo "Please choose your Proton version that you use to run Rocksmith:"
	print_orange "0) Proton 10.0 [Default]"
	echo "1) Proton - Experimental"
	echo "2) Proton 9.0"
	echo "3) Proton 8.0"

	read -p "Choose your Proton Version (0-3): " USERPROTONVER

	if validate_proton_input "$USERPROTONVER"; then
		case $USERPROTONVER in
		0)
			PROTONVER="Proton 10.0"
			FILES_OR_DIST="files"
			;;
		1)
			PROTONVER="Proton - Experimental"
			FILES_OR_DIST="files"
			;;
		2)
			PROTONVER="Proton 9.0"
			FILES_OR_DIST="files"
			;;
		3)
			PROTONVER="Proton 8.0"
			FILES_OR_DIST="dist"
			;;
		esac

		PROTONPATH="${STEAMPATH}/steamapps/common/${PROTONVER}"
		WINE="${PROTONPATH}/${FILES_OR_DIST}/bin/wine"
		WINE64="${PROTONPATH}/${FILES_OR_DIST}/bin/wine64"

		print_blue "Using $PROTONVER"
	else
		print_red "You need to select a value between 0 and 2, please try again"
		choose_proton
	fi
}

validate_rsasio_input() {
	if [[ -z $1 || $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		return 0
	else
		return 1
	fi
}

choose_rsasio() {
	if [ "$RSASIOVER_SET" = true ]; then
		return
	fi

	read -p "Override RS_ASIO Version [$(print_orange ${RSASIOVER})]: " USER_RSASIOVER
	if validate_rsasio_input "$USER_RSASIOVER"; then
		RSASIOVER=${USER_RSASIOVER:-$RSASIOVER}
		print_blue "Using $RSASIOVER"
	else
		print_red "The value is not in the correct format: x.y.z"
		choose_rsasio
	fi
}

parse_args() {
	normalized=()

	while [ "$#" -gt 0 ]; do
		case "$1" in
		--steampath=*) normalized+=("-s" "${1#--steampath=}") ;;
		--wineprefix=*) normalized+=("-w" "${1#--wineprefix=}") ;;
		--rsasiover=*) normalized+=("-r" "${1#--rsasiover=}") ;;
		--protonpath=*) normalized+=("-p" "${1#--protonpath=}") ;;
		--protontype=*) normalized+=("-P" "${1#--protontype=}") ;;
		--cdlc) normalized+=("-C") ;;
		--mods) normalized+=("-M") ;;
		-C) normalized+=("-C") ;;
		-M) normalized+=("-M") ;;
		-s | -w | -r | -p | -P)
			if [ -z "${2:-}" ] || [[ "$2" == -* ]]; then
				echo "Error: $1 requires an argument" >&2
				exit 2
			fi
			normalized+=("$1" "$2")
			shift
			;;
		--* | -*)
			echo "Unknown option: $1" >&2
			exit 2
			;;
		*)
			normalized+=("$1")
			;;
		esac
		shift
	done

	set -- "${normalized[@]}"

	PROTONTYPE_SET=false

	while getopts ":s:w:r:p:P:CM" opt; do
		case "$opt" in
		s) STEAMPATH="$OPTARG" ;;
		w) WINEPREFIX="$OPTARG" ;;
		r)
			RSASIOVER="$OPTARG"
			if ! validate_rsasio_input "$RSASIOVER"; then
				echo "Invalid RSASIO version format: $RSASIOVER (correct format: x.y.z)" >&2
				exit 2
			fi
			RSASIOVER_SET=true
			;;
		p)
			PROTONPATH="$OPTARG"
			PROTONPATH_SET=true
			;;
		P)
			PROTONTYPE="$OPTARG"
			PROTONTYPE_SET=true
			case "$PROTONTYPE" in
			files | dist) ;;
			*)
				echo "Invalid type of Proton: $PROTONTYPE (allowed: files or dist)" >&2
				exit 2
				;;
			esac
			;;
		C) INSTALL_CDLC=true ;;
		M) INSTALL_MODS=true ;;
		:)
			echo "Option -$OPTARG requires an argument" >&2
			exit 2
			;;
		\?)
			echo "Unknown option: -$OPTARG" >&2
			exit 2
			;;
		esac
	done

	if [ "$PROTONPATH_SET" = true ] && [ "$PROTONTYPE_SET" != true ]; then
		echo "Error: -p/--protonpath requires -P/--protontype to be set" >&2
		exit 2
	fi
	if [ "$PROTONTYPE_SET" = true ] && [ "$PROTONPATH_SET" != true ]; then
		echo "Error: -P/--protontype may only be used with -p/--protonpath" >&2
		exit 2
	fi
}

greet() {
	print_blue "======== Rocksmith 2014 - Wineasio patcher for NixOS ========"
}

print_system_info() {
	print_blue "======== System Info ========"
	echo "NixOS $(nixos-version) [$(getconf LONG_BIT)-bit]"
	echo "Kernel $(uname -r)"
	echo "Wine $("${WINE}" --version)"
	echo "Wine64 $("${WINE64}" --version)"

	echo "RS_ASIO (Desired) ${RSASIOVER}"
	echo "Proton (Desired) ${PROTONVER}"
}

check_installed() {
	if which "$1" >/dev/null 2>&1; then
		echo "$1 $(print_green present)"
	else
		print_red "Required $1 is not installed!"
		exit 1
	fi
}

check_and_prepare() {
	print_blue "======== Check and prepare ========"
	check_passed=true

	CHECKPATHS=(
		"$WINEPREFIX"
		"$WINEASIOPATH"
		"$WINEASIO32PATH"
		"$STEAMPATH"
		"$PROTONPATH"
		"/lib/wine"
		"${STEAMPATH}/steamapps/compatdata/221680"
		"${STEAMPATH}/steamapps/compatdata/221680/pfx/"
	)

	CHECKFILES=(
		"$WINE"
		"$WINE64"
		"/usr/lib32/libjack.so"
	)

	CHECKPROGRAMS=(
		"steam"
		"steam-run"
		"pipewire"
	)

	echo "=== Paths ==="

	for path in "${CHECKPATHS[@]}"; do
		if [ ! -d "${path}" ]; then
			echo "Directory ${path} ... $(print_red "NOT found!")"
			check_passed=false
		else
			echo "Directory ${path} ... $(print_green OK)"
		fi
	done

	echo "=== Files ==="

	for file in "${CHECKFILES[@]}"; do
		if [ ! -f "${file}" ]; then
			echo "File ${file} ... $(print_red "NOT found!")"
			check_passed=false
		else
			echo "File ${file} ... $(print_green OK)"
		fi
	done

	for dll in "${WINEASIODLLS[@]}"; do
		if [ ! -f "${WINEASIOPATH}${dll}" ] && [ ! -f "${WINEASIO32PATH}${dll}" ]; then
			echo "File ${dll} ... $(print_red NOT found!)"
			check_passed=false
		else
			echo "File ${dll} ... $(print_green OK)"
		fi
	done

	for program in "${CHECKPROGRAMS[@]}"; do
		check_installed "${program}"
	done

	if [ "$check_passed" = false ]; then
		print_red "A check failed. Exiting the program."
		exit 1
	fi

	read -p "This script will add wineasio to Proton and Rocksmith, register it and install RS_ASIO. Do you want to continue? (y/N): " user_input
	user_input=$(echo "$user_input" | tr '[:lower:]' '[:upper:]')
	if [ "$user_input" != "Y" ]; then
		print_red "Exiting..."
		exit 0
	fi
}

register_dll() {
	echo "[Wineasio] Registering ${1}"
	"${2}" regsvr32 "${1}" >/dev/null 2>&1
}

safe_copy() {
	echo "[COPY FILE] $1 -> $2"
	rm -rf "$2"
	cp "$1" "$2"
}

patch_wineasio_32bit() {
	echo "[Wineasio] Applying Patch for 32-bit"
	if [ -e "${WINEASIOPATH}${1}" ]; then
		safe_copy "${WINEASIOPATH}${1}" "${PROTONPATH}/${FILES_OR_DIST}/lib/wine${1}"
	elif [ -e "${WINEASIO32PATH}${1}" ]; then
		safe_copy "${WINEASIO32PATH}${1}" "${PROTONPATH}/${FILES_OR_DIST}/lib/wine${1}"
	fi
	if [[ $1 == *.so ]]; then
		local wineasio_dll

		wineasio_dll=$(echo "${WINEASIOPATH}${1}" | sed -e 's|/i386-unix/wineasio32.dll.so|/i386-windows/wineasio32.dll|g')

		if [ -e "${WINEASIOPATH}${1}" ] && [ -e "${wineasio_dll}" ]; then
			echo "[Wineasio 32-bit] Copying ${wineasio_dll} in ${WINEPREFIX}/drive_c/windows/syswow64/wineasio32.dll"
			safe_copy "${wineasio_dll}" "${WINEPREFIX}/drive_c/windows/syswow64/wineasio32.dll"
			register_dll "$wineasio_dll" "$WINE"
		elif [ -e "${WINEASIO32PATH}${1}" ] && [ -e "${wineasio_dll}" ]; then
			echo "[Wineasio 32-bit] Copying ${wineasio_dll} in ${WINEPREFIX}/drive_c/windows/syswow64/wineasio32.dll"
			safe_copy "${wineasio_dll}" "${WINEPREFIX}/drive_c/windows/syswow64/wineasio32.dll"
			register_dll "$wineasio_dll" "$WINE"
		fi
	fi
}

patch_wineasio_64bit() {
	echo "[Wineasio] Applying Patch for 64-bit"

	if [ -e "${PROTONPATH}/${FILES_OR_DIST}/lib64/" ]; then
		safe_copy "${WINEASIOPATH}${1}" "${PROTONPATH}/${FILES_OR_DIST}/lib64/wine${1}"
	elif [ -e "${PROTONPATH}/${FILES_OR_DIST}/lib/" ]; then
		safe_copy "${WINEASIOPATH}${1}" "${PROTONPATH}/${FILES_OR_DIST}/lib/wine${1}"
	fi

	if [[ $1 == *.so ]]; then
		if [ ! -d "${WINEPREFIX}/drive_c/windows/syswow64" ]; then
			echo "[Wineasio] Skipping $1 because ${WINEPREFIX} is not a 64-bit system"
			return
		fi

		local wineasio_dll

		wineasio_dll=$(echo "${WINEASIOPATH}${1}" | sed -e 's|/x86_64-unix/wineasio64.dll.so|/x86_64-windows/wineasio64.dll|g')
		if [ -e "${WINEASIOPATH}${1}" ] && [ -e "${wineasio_dll}" ]; then
			echo "[Wineasio 64-bit] Copying ${wineasio_dll} in ${WINEPREFIX}/drive_c/windows/system32/wineasio64.dll"
			safe_copy "${wineasio_dll}" "${WINEPREFIX}/drive_c/windows/system32/wineasio64.dll"
			register_dll "$wineasio_dll" "$WINE64"
		fi
	fi
}

patch_wineasio() {
	print_blue "======== Wineasio ========"

	echo "[Wineasio] Install Wineasio"
	for dll in "${WINEASIODLLS[@]}"; do
		if echo "$dll" | grep -q "32"; then
			patch_wineasio_32bit "$dll"
		elif echo "$dll" | grep -q "64"; then
			patch_wineasio_64bit "$dll"
		else
			echo "$dll doesn't contain 32 or 64 in its name. Can't choose if 32 or 64 bit."
		fi
	done
}

patch_rs_asio() {
	print_blue "======== RS_ASIO ========"

	echo "[RS_ASIO] Dowload RS_ASIO"
	if [ ! -f "release-${RSASIOVER}.zip" ]; then
		wget "https://github.com/mdias/rs_asio/releases/download/v${RSASIOVER}/release-${RSASIOVER}.zip" >/dev/null 2>&1
	fi

	echo "[RS_ASIO] Unzip"
	unzip "release-${RSASIOVER}.zip" -d RS_ASIO

	sed -i 's/Driver=[^ ]*/Driver=wineasio-rsasio/g' "RS_ASIO/RS_ASIO.ini"

	echo "[RS_ASIO] Copying RS_ASIO to Rocksmith installation"
	cp -a "RS_ASIO/"* "${STEAMPATH}/steamapps/common/Rocksmith2014/"
}

install_cdlc() {
	if [ "$INSTALL_CDLC" = false ]; then
		return
	fi

	print_blue "========= CDLC ========="

	echo "[CDLC] Download CDLC Enabler"
	wget "https://ignition4.customsforge.com/tools/download/cdlc-enabler" -O "${WINEPREFIX}drive_c/${CDLC_INSTALLER}" 2>&1

	echo "[CDLC] Running CDLC Enabler"
	"${WINE}" "${WINEPREFIX}drive_c/${CDLC_INSTALLER}" >/dev/null 2>&1
}

install_mods() {
	if [ "$INSTALL_MODS" = false ]; then
		return
	fi

	print_blue "======== Mods ========"

	echo "[Mods] Download Mod Installer"
	wget "https://github.com/Lovrom8/RSMods/releases/latest/download/RS2014-Mod-Installer.exe" -O "${WINEPREFIX}drive_c/${MODS_INSTALLER}" 2>&1

	echo "[Mods] Running Mod Installer"
	"${WINE}" "${WINEPREFIX}drive_c/${MODS_INSTALLER}" >/dev/null 2>&1
}

finalise() {
	print_blue "======== DONE ========"

	echo "Patch applied, you can now configure Rocksmith"

	echo "First, check that the RS_ASIO.ini file is correct"
	echo
	echo "Finally, add the following launch option to Rocksmith on Steam"
	echo
	echo "================================================================"
	echo "${LAUNCH_OPTIONS}"
	echo "================================================================"
	echo
	echo "Alternatively, for rs-autoconnect, add the following launch option"
	echo "================================================================"
	echo "${ALT_LAUNCH_OPTIONS}"
	echo "================================================================"
	echo
	echo "Before launching the game, delete Rocksmith.ini"
}

clean() {
	rm "release-${RSASIOVER}.zip"
	rm -rf RS_ASIO
}

################### Execute ###################
greet
parse_args "$@"
choose_proton
choose_rsasio
print_system_info
check_and_prepare
patch_wineasio
patch_rs_asio
install_cdlc
install_mods
clean
finalise

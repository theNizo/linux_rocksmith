#!/bin/bash

trap "exit" INT

# number echos are meant for debugging purposes, to find the point where it doeesn't behave properly
# basically, it's a bunch of replacements for parts with a specific name. the name in 000-<name>-000 and the folder names match.
# list all used variables with: grep -oiP "000-.*-000" base.md
# the only more complicated part is install wineasio, which has a couple variables more.

echo "-1"
path=../guides/setup

for dist in arch deb deck fed; do
	for sound in native pipewire; do
		echo 0
		echo "$dist; $sound" # print out, which file is worked on, so it's easier to debug.
		if [ "$dist" = "fed" ] && [ "$sound" = "native" ]; then
			echo "recognized fed-native loop, skipping."
			continue
		fi
		filename=$path/$dist-$sound.md
		cp base.md $filename # BASE SHOULD NEVER BE CHANGED BY THIS SCRIPT
		echo 1
		sed -i "s/000-title-000/cat title\/${dist}-${sound}/e" $filename
		echo 2
		sed -i "s/000-install-necessary-000/cat install-necessary\/${dist}-${sound}/e" $filename #needs fixing

		echo 3
		if [ "$dist" = "deck" ] && [ "$sound" = "native" ]; then
			echo "deck native post install"
			sed -i "s/000-install-necessary-post-000/cat install-necessary-post\/deck-native/e" $filename #needs fixing
		else
			sed -i "s/000-install-necessary-post-000/cat install-necessary-post\/base/e" $filename #needs fixing
		fi

		echo 4
		# wineasio install - more complicated section, write later
		if ! [ "$dist" = "deb" ]; then # if appliccable
			echo 5
			sed -i "s/000-wineasio-install-000/cat wineasio-install\/base/e" $filename # set base
			if [ "$dist" = "fed" ]; then
				echo "fedora wineasio install"
				sed -i "s/000-base-devel-000//" $filename
				echo 6
				sed -i "s/000-fedora-makefile-000/cat wineasio-install\/fedora-makefile/e" $filename
			else
				echo "non-fedora wineasio install"
				sed -i "s/000-base-devel-000/cat wineasio-install\/base-devel\/${dist}-${sound}/e" $filename
				sed -i "s/000-fedora-makefile-000//" $filename
			fi
			if [ "$dist" = "deck" ] && [ "$sound" = "pipewire" ]; then
				echo "deck pipewire reinstall"
				sed -i "s/000-deck-pipewire-reinstall-000/cat wineasio-install\/deck-pipewire-reinstall/e" $filename
			else
				echo 7
				sed -i "s/000-deck-pipewire-reinstall-000//" $filename
			fi
		else
			echo "debian wineasio install"
			sed -i "s/000-wineasio-install-000//" $filename #needs fixing
		fi

		echo 8
		sed -i "s/000-set-up-jack-000/cat set-up-jack\/${sound}/e" $filename
		echo 9
		sed -i "s/000-steam-running-000/cat steam-running\/${sound}/e" $filename
		echo 10
		sed -i "s/000-ldpreload-command-000/cat ldpreload-command\/${sound}/e" $filename
		echo 11
		sed -i "s/000-connect-sound-000/cat connect-sound\/${sound}/e" $filename
		echo 12
		sed -i "s/000-lutris-env-000/cat lutris-env\/${sound}/e" $filename

		echo "replace inline"
		./replace-inline.sh $dist $sound $filename
	done
done

# This will list all the file names, regardless of missing something, or not. If there's a tag that's not replaced, it will appear below the according filename.
echo 13
echo "missing replacements, by file:"
for file in $(ls $path); do
	echo $file
	cat $path/$file | grep -P "000-"
done

exit 0

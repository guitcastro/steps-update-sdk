#!/bin/bash
set -e

function checkIfIsInstalled {
  if [ -d "$ANDROID_HOME/$1/$2" ] ; then
    return 0
  else
    return 1
  fi
}

function appendFilter {
	if [ -z "$FILTER" ]; then
		FILTER=$1
	else
		FILTER="$FILTER,$1"
	fi
}

function checkIfIsSystemImageInstalled {
	local imageName=$1
	regex='(sys-img)-([^\"]*)-(android-?([^\"]*)-)([0-9][0-9])'
	if [[ $imageName =~ $regex ]] ; then
		local arch=${BASH_REMATCH[2]}
		local device_type='default'
		if [ -n "${BASH_REMATCH[4]}" ]; then
			# TV or Wear
			local device_type="android-${BASH_REMATCH[4]}"
		fi
		local version=${BASH_REMATCH[5]}
		#echo $imageName
		local dir="$ANDROID_HOME/system-images/android-$version/$device_type/$arch"
		if [ -d "$dir" ]; then
			return 0
		fi
	else
		echo 'Regex failed'
	fi
	return 1
}

# Android SDK Build-tools

if [ "${tools}" = "on" ]; then
	appendFilter 'tools'
fi

# Android SDK Platform-tools

if [ "${platform_tools}" = "stable" ]; then
	appendFilter 'platform-tools'
fi
if [ "${platform_tools}" = "preview" ]; then
	appendFilter 'platform-tools-preview'
fi
if [ "${platform_tools}" = "both" ]; then
	appendFilter 'platform-tools'
	appendFilter 'platform-tools-preview'
fi

# Android SDK Platform

IFS=',' read -ra ADDR <<< "$sdk_version"
for i in "${ADDR[@]}"; do
	if checkIfIsInstalled "platforms" "android-$i" ; then
	    echo "Android SDK Platform version $i is installed, skipping"
	else
		appendFilter "android-$i"
	fi
done

# Android SDK Build-tools versions

IFS=',' read -ra ADDR <<< "$build_tools"
for i in "${ADDR[@]}"; do
	if checkIfIsInstalled "build-tools" "$i" ; then
	    echo "Android SDK Build-tools version $i is installed, skipping"
	else
		appendFilter "build-tools-$i"
	fi
done

# SystemImage

IFS=',' read -ra ADDR <<< "$system_images"
for i in "${ADDR[@]}"; do
	if checkIfIsSystemImageInstalled "$i" ; then
	    echo "$i is already installed, skipping"
	else
		appendFilter "$i"
	fi
done

echo "updating sdk using filter = $FILTER"


# Prevent erros when accepting the license as suggest in:
# http://stackoverflow.com/a/31900427/1107651
( sleep 5 && while [ 1 ]; do sleep 1; echo y; done ) \
    | android update sdk --no-ui --all --filter ${FILTER}

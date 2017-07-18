#!/bin/bash
set -e

function vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi


    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done

    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi

        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi

    done



    return 0
}


function getLastedSupportLibraryRevision {
	packages=$(${ANDROID_HOME}/tools/bin/sdkmanager --list --verbose)
	line=$(grep -A1 "Android Support Repository" <<< "$packages")
	line=$(grep "Version:" <<< "$line")
	echo ${line: -6}
}

function getLocalSupportLibraryRevision {
	getPackageRevisionVersionFromFile "$ANDROID_HOME/extras/android/m2repository/source.properties"
}

function getPackageRevisionVersionFromFile {
	local file=$1
	local version=0

	if [ -f "$file" ]
	then

	while IFS='=' read -r key value
	  do
	  	if [ "$key" = "Pkg.Revision" ]; then
	  		version=$value
	  	fi
	done < "$file"
	fi

	echo $version

}

function checkIfIsInstalled {
  if [ -d "$ANDROID_HOME/$1/$2" ] ; then
    return 0
  else
    return 1
  fi
}

function appendFilter {
	if [ -z "$FILTER" ]; then
		FILTER=\"$1\"
	else
	    FILTER+=' '
		FILTER+=\"$1\"
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
		appendFilter "platforms;android-$i"
	fi
done

# Android SDK Build-tools versions

IFS=',' read -ra ADDR <<< "$build_tools"
for i in "${ADDR[@]}"; do
	if checkIfIsInstalled "build-tools" "$i" ; then
	    echo "Android SDK Build-tools version $i is installed, skipping"
	else
		appendFilter "build-tools;$i"
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

# Support library

lastedVersion="$(getLastedSupportLibraryRevision)"
localVersion="$(getLocalSupportLibraryRevision)"

if [ $localVersion = 0 ] ; then
	echo "Local Support library repository not found"
	appendFilter "extras;android;m2repository"
else
	echo "Local Support library repository revision is ${localVersion}"
	echo "Lasted Support library repository revision is ${lastedVersion}"

	vercomp "$localVersion" "$lastedVersion"

	if [ $? -gt 1 ] ; then
		appendFilter "extra-android-m2repository"
	else
		echo "Support library repository is up to date"
	fi
fi

# Apply changes

if [ -z "$FILTER" ]; then
	echo "No packages to install"
else

  # Prevent erros when accepting the license as suggest in:
	# http://stackoverflow.com/a/31900427/1107651
	( sleep 3 && while [ 1 ]; do sleep 1; echo y; done ) \
	    | ${ANDROID_HOME}/tools/bin/sdkmanager --licenses

  echo "updating sdk using filter = $FILTER"
	eval "${ANDROID_HOME}/tools/bin/sdkmanager $FILTER"
fi

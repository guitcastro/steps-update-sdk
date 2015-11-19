#!/bin/bash

set -e

tools=	
platform_tools=both
platform=23,22,20

function appendFilter {
	if [ -z "$FILTER" ]; then
		FILTER=$1
	else
		FILTER="$FILTER,$1"
	fi			
}

# Android SDK Build-tools

if [ "${tools}" = 'on' ]; then
	appendFilter 'tools'
fi

# Android SDK Platform-tools

if [ "${platform_tools}" = 'stable' ]; then
	appendFilter 'platform-tools'
fi
if [ "${platform_tools}" = 'preview' ]; then
	appendFilter 'platform-tools-preview'
fi
if [ "${platform_tools}" = 'both' ]; then
	appendFilter 'platform-tools'
	appendFilter 'platform-tools-preview'
fi

# Android SDK Platform-

IFS=',' read -ra ADDR <<< "$platform"
for i in "${ADDR[@]}"; do
    appendFilter "android-$i"
done

# Android SDK Build-tools versions

IFS=',' read -ra ADDR <<< "$build_tools"
for i in "${ADDR[@]}"; do
    appendFilter "build-tools-$i"
done

# SystemImage

IFS=',' read -ra ADDR <<< "$system_images"
for i in "${ADDR[@]}"; do
    appendFilter "$i"
done

echo "updating sdk using filter = $FILTER"

# Prevent erros when accepting the license as suggest in:
# http://stackoverflow.com/a/31900427/1107651
( sleep 5 && while [ 1 ]; do sleep 1; echo y; done ) \
    | android update sdk --no-ui --all \
    --filter ${FILTER}
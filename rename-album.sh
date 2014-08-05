#!/bin/bash

if [ "x$1" = "x" ]
then
	echo "Provide a target album-named directory" >&2
	exit 1
fi

set -eu

if [ ! -d "$1" ]
then
	echo "'$1' not a directory" >&2
	exit 1
fi

declare -a TOOLS=(abcde eyeD3)
for t in ${TOOLS[@]}
do
	if [ ! -x "`which $t 2> /dev/null`" ]
	then
		echo "Required tool '$t' not found or not executable" >&2
		exit 1
	fi
done

OLD="$1"
NEW="$2"
ABCDE_CONF='/etc/abcde.conf'

# Read the ABCDE configuration file to follow the same munging convention!
. "$ABCDE_CONF"

find "$OLD" -type f -name '*.mp3' -print0 | \
xargs -0 -- eyeD3 -2 -A "$NEW"

NEW="`mungefilename $NEW`" # Reset it now
mv -f "$OLD" "$NEW"

exec embed-album-art "$NEW"

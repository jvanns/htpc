#!/bin/bash

set -eu

SELF="$0"
MODE="${1:-}"
INFO_FILE="/tmp/`basename $SELF`.inf"

format_files() {
	while IFS=$'|' read enclib encapp file album artist title format bdep brat
	do
		if [[ "$enclib" =~ ^itunes ]] || [[ "$encapp" =~ ^itunes ]]; then
			continue
		fi
		echo -e "$file\t$album"
	done
}

identify_files() {
	shopt -s nocasematch

	for f in "$@"
	do
		mediainfo --Inform="file://$INFO_FILE" "$f"
	done | format_files
}

bootstrap_migration() {
	local l=64
	local p=`getconf _NPROCESSORS_ONLN`

	echo -ne 'General;%Encoded_Library%|%Encoded_Application%|' > "$INFO_FILE"
	echo -e  '%CompleteName%|%Album%|%Performer%|%Track%|'      >> "$INFO_FILE"
	echo -e  'Audio;%Format%|%BitDepth%|%BitRate%'              >> "$INFO_FILE"

	trap "rm -f $INFO_FILE" EXIT

	find "$1" -type f \
		\! -name '*.mp4' \
		-print0 \
	| xargs -0 -P$p -n$l -- $SELF zygote
}

usage() {
	echo "`basename "$SELF"`: copy <from directory> <to directory>"
	exit 1
}

if [ "$MODE" = 'copy' ]; then
	shift
	bootstrap_migration "$1" "$2"
elif [ "$MODE" = 'zygote' ]; then
	shift
	identify_files "$@"
elif [ "x${MODE}" = 'x' ]; then
	usage
else
	echo "Unknown mode '$MODE'" >&2
	usage
fi

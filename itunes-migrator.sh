#!/bin/bash

set -eu

SELF="$0"
MODE="${1:-}"

format_files() {
	while IFS=$'|' read encoder file album artist title format bdepth brate
	do
		echo -e "$file\t$album"
	done | sort -t $'\t' -k2
}

identify_files() {
	for f in "$@"
	do
cat <<EOF | mediainfo --Inform='file:///dev/stdin' "$f"
General;%Encoded_Library%|%CompleteName%|%Album%|%Performer%|%Track name%|
Audio;%Format%|%BitDepth%|%BitRate%
EOF
	done | grep -iv '^itunes.*|/' | format_files
}

bootstrap_migration() {
	local l=64
	local p=`getconf _NPROCESSORS_ONLN`

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

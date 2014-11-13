#!/bin/bash

set -eu

MODE="${1:-}"
SELF="`readlink -f $0`"
INFO_FILE="/tmp/`basename $SELF`.inf"

# A direct copy of the mungefilename() function in abcde.conf
munge()
{
	echo "$@" | tr / _ | tr -d \'\"\?\[:cntrl:\] | tr "[:upper:]" "[:lower:]"
}

format_files() {
	local e=0

	while IFS=$'|' read enclib encapp file album artist title format bdep brat
	do
		if [[ "$enclib" =~ ^itunes ]] || [[ "$encapp" =~ ^itunes ]]; then
			continue
		fi

		if [ "x${album}" = "x" ]; then
			echo -e "ERR_NO_ALBUM\t$file\t$artist\t$title" >&2
			e=1
		fi

		if [ "x${artist}" = "x" ]; then
			echo -e "ERR_NO_ARTIST\t$file\t$album\t$title" >&2
			e=1
		fi

		if [ "x${title}" = "x" ]; then
			echo -e "ERR_NO_TITLE\t$file\t$album\t$artist" >&2
			e=1
		fi

		if [ $e -eq 1 ]; then 
			e=0
         continue
		fi

		# Follow the same format as OUTPUTFORMAT in abcde.conf
		suffix="`munge $title`"
		prefix="`munge $album`/`munge $artist`"
		echo install -D "$file" "./${prefix}/${suffix}.${file#*.}"
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

	cd "$2"
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

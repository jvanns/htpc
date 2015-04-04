#!/bin/bash

set -eu

MODE="${1:-}"
SELF="`readlink -f $0`"
NAME="`basename $SELF`"
INFO_FILE="/tmp/${NAME}.inf"
PATH_LOG="${HOME}/${NAME}-path.log"
COPY_LOG="${HOME}/${NAME}-copy.log"

# A direct copy of the mungefilename() function in abcde.conf
munge()
{
	echo "$@" | tr / _ | tr -d \'\"\?\[:cntrl:\] | tr "[:upper:]" "[:lower:]"
}

format_files() {
	local e=0

	while IFS=$'|' read enclib encapp file genre album artist title format bdep brat
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

		if [ "x${genre}" = "x" ]; then
			echo -e "ERR_NO_GENRE\t$file\t$album\t$artist\t$title" >&2
			e=1
		fi

		if [ $e -eq 1 ]; then 
			e=0
			continue
		fi

		# Follow the same format as OUTPUTFORMAT in abcde.conf
		suffix="`munge $title`"
		prefix="`munge $genre`/`munge $artist`/`munge $album`"
		echo "./${prefix}/${suffix}.${file#*.}" >> "$PATH_LOG"
		install -D "$file" "./${prefix}/${suffix}.${file#*.}" | tee -a "$COPY_LOG"
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

	echo -n 'General;%Encoded_Library%|%Encoded_Application%|' > "$INFO_FILE"
	echo '%CompleteName%|%Genre%|%Album%|%Performer%|%Track%|' >> "$INFO_FILE"
	echo 'Audio;%Format%|%BitDepth%|%BitRate%'                 >> "$INFO_FILE"

	trap "rm -f $INFO_FILE" EXIT

	cd "$2"
	find "$1" -type f \
		\! -name '*.mp4' \
		\! -name '*.m4v' \
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

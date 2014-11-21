#!/bin/bash

TAB="`echo -ne '\t'`"
DB_DIR="${ID3MAP:-/etc/id3map}"

if [ "$#" != "2" ]
then
	echo "Provide a tag name to re-map and a current tag value " >&2
	exit 1
fi

set -eu

remap() {
	db="${DB_DIR}/${1}.db"

	if [ ! -s "$db" ]
	then
		echo "The '$1' tag mapping file '$db' not found or empty" >&2
		exit 1
	fi

	grep -i "^${2}${TAB}" "$db" | cut -f2
}

case "$1" in
genre)
	remap "$1" "$2"
	;;
*)
	echo "Invalid sub-command" >&2
	exit 1
	;;
esac


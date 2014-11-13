#!/bin/bash

if [ "x$1" = "x" ]
then
	echo "Provide the source genre" >&2
	exit 1
fi

set -eu

TAB="`echo -ne '\t'`"
DB="${ID3_GENRE_MAP:-/etc/id3-genre-map.db}"

if [ ! -s "$DB" ]
then
	echo "Genre mapping DB file '$DB' not found or empty" >&2
	exit 1
fi

grep -i "^${1}${TAB}" "$DB" | cut -f2

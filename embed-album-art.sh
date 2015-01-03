#!/bin/bash
#
# This simple script will fetch the cover art for the album information
# provided on the command line. It will then download that cover image,
# and place it into the temporary directory. The term "album information" is
# really the album-named relative path of the current directory. 
#
# The second stage is to embed the binary data of this image file into
# the ID3v2 APIC frame, into every file beneath the given directory.
#

if [ "x$1" = "x" ]
then
	echo "Provide a target album-named, relative directory" >&2
	exit 1
fi

set -eu

if [ ! -d "$1" ]
then
	echo "'$1' not a directory" >&2
	exit 1
fi

declare -a TOOLS=(perl eyeD3 wget)
for t in ${TOOLS[@]}
do
	if [ ! -x "`which $t 2> /dev/null`" ]
	then
		echo "Required tool '$t' not found or not executable" >&2
		exit 1
	fi
done

# Parent Path
PP=`pwd`
# Grandparent Path
GPP=`readlink -f "${PWD}/../"`

ALBUM=`echo "$1" | sed 's/ [[(][Dd]is[ck] [0-9][])]$//'`
ARTIST="${PP##*/}"
GENRE="${GPP##*/}"
TERM="$ALBUM"

if [ "$GENRE" = 'soundtrack' ]; then
	TERM="$ALBUM $GENRE"
elif [ "$ARTIST" != 'compilations' ]; then
	TERM="$ARTIST $ALBUM"
fi

QUERY="${TERM// /+}"
IMG="${TMP:-/tmp}/album-art.jpg"
PAGE='http://www.albumart.org/index.php'
ESCAPED="`perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' $QUERY`"
URL="${PAGE}?searchk=${ESCAPED}&itempage=1&newsearch=1&searchindex=Music"

echo "Searching for: [$QUERY]"
echo "Searching ... [$URL]"

COVERURL=`wget -qO - "$URL" | grep -m1 -E -o \
"http://ecx.images-amazon.com/images/I/*/[%0-9a-zA-Z.,-]*.jpg"`

if [ "x$COVERURL" = "x" ]
then
	echo "Failed to find album art for $QUERY" >&2
	exit 1
fi

echo "Cover URL: [$COVERURL]"
wget -qO - "$COVERURL" 1> "$IMG"
[ $? -ne 0 ] && [ ! -s "$IMG" ] && exit 1

echo "Embedding ... [`stat -c %s $IMG` bytes]"
find "$1" -type f -name '*.mp3' -print0 | xargs -0 -I % -- sh -c \
"eyeD3 -2 --remove-images '%';eyeD3 -2 --add-image='${IMG}:FRONT_COVER' '%'"

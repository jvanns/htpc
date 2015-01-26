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

# Default search parameters
PAGE=1
INDEX=1
COUNTRY='gb'

# These default to empty as they are generally discovered during search
IMG=
COVERURL=

while getopts 'g:u:c:p:i:h' OPTION; do
	case $OPTION in
	g)
		IMG="$OPTARG"
		;;
	u)
		COVERURL="$OPTARG"
		;;
	c)
		COUNTRY="$OPTARG"
		;;
	p)
		PAGE="$OPTARG"
		;;
	i)
		INDEX="$OPTARG"
		;;
	h)
		echo -e "Usage: $0 [options] <album directory>\nOptions:"
		echo -e "   -h                 Help! Print this message then exit"
		echo -e "   -g <image path>    Embed this image, do not download"
		echo -e "   -u <url>           Provide an alternative download URL"
		echo -e "----- search parameters only -----"
		echo -e "   -c <country>       Set the country for album art choice"
		echo -e "   -p <page number>   Result page to choose album art from"
		echo -e "   -i <index>         Index of cover choice from results page"
		exit 0
		;;
	?)
		exit 1
		;;
	esac
done
shift $(($OPTIND - 1))

if [ "x$1" = "x" ]; then
	echo "Provide a target album-named, relative directory" >&2
	exit 1
fi

set -eu

if [ ! -d "$1" ]; then
	echo "'$1' not a directory" >&2
	exit 1
fi

declare -a TOOLS=(perl eyeD3 curl)
for t in ${TOOLS[@]}
do
	if [ ! -x "`which $t 2> /dev/null`" ]; then
		echo "Required tool '$t' not found or not executable" >&2
		exit 1
	fi
done

# Path
P="$1"
# Parent Path
PP=`pwd`
# Grandparent Path
GPP=`readlink -f "${PWD}/../"`

embed_img() {
	echo "Embedding ... [`stat -c %s $IMG` bytes]"
	find "$1" -type f -name '*.mp3' -print0 | xargs -0 -I % -- sh -c \
	"eyeD3 -2 --remove-images '%';eyeD3 -2 --add-image='${IMG}:FRONT_COVER' '%'"
}

if [ "x${IMG}" != "x" ]; then
	if [ ! -r "$IMG" ]; then
		echo "'$IMG' not a file or cannot be read" >&2
		exit 1
	fi

	embed_img "$P"
	exit $?
fi

# Set location of resulting image file
IMG="${TMP:-/tmp}/album-art.jpg"

# Build search term
ALBUM=`echo "$1" | sed 's/ [[(][Dd]is[ck] [0-9][])]$//'`
ARTIST="${PP##*/}"
GENRE="${GPP##*/}"
TERM="${ALBUM%/}"

if [ "$GENRE" = 'soundtrack' ]; then
	TERM="${ALBUM%/} $GENRE"
elif [ "$ARTIST" != 'compilations' ]; then
	TERM="$ARTIST ${ALBUM%/}"
fi

download_img() {
	echo "Cover URL: [${1}]"
	curl -s -o "$IMG" "$1"
	[ $? -eq 0 ] && [ -s "$IMG" ] && return 0

	return 1
}

# The short variable names are;
# c = Cover art URLs (an array)
# d = Domain
# u = URL
# p = Pattern
search_img() {
	local -a c=()
	d='www.seekacover.com'
	u="${d}/cd/`perl -MURI::Escape -e "print uri_escape('$1');"`/${PAGE}"
	p='<img src="http://ecx.images-amazon.com/images/I/*/[%0-9a-zA-Z.,-]*.jpg"'

	echo "Searching for: [$1]"
	echo "Searching ... [$u]"

	c=(`\
		curl -s "$u" \
		grep -Eo "$p" \
		sed -E 's/^<img src="(.*)"$/\1/' \
	`)

	if [ ${#c[@]} -eq 0 ]; then
		echo "Failed to find album art for $1" >&2
		return 1
	fi

	COVERURL="${c[$(($INDEX - 1))]}"
}

if [ "x${COVERURL}" = "x" ]; then
	search_img "$TERM"
	[ $? -ne 0 ] && exit 1
fi

download_img "$COVERURL"
embed_img "$P"

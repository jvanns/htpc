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

PAGE=1
INDEX=1

while getopts 'p:i:h' OPTION; do
   case $OPTION in
   p)
      PAGE="$OPTARG"
      ;;
   i)
      INDEX="$OPTARG"
      ;;
   h)
      echo -e "Usage: $0 [options] <album directory>\nOptions:"
      echo -e "   -h                 Help! Print this message then exit"
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

declare -a TOOLS=(perl eyeD3 curl)
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
TERM="${ALBUM%/}"

if [ "$GENRE" = 'soundtrack' ]; then
	TERM="${ALBUM%/} $GENRE"
elif [ "$ARTIST" != 'compilations' ]; then
	TERM="$ARTIST ${ALBUM%/}"
fi

IMG="${TMP:-/tmp}/album-art.jpg"
QUERY=`perl -MURI::Escape -e "print uri_escape('$TERM');"`
PATTERN='<a href="http://ecx.images-amazon.com/images/I/*/[%0-9a-zA-Z.,-]*.jpg"'
URL="http://www.albumart.org/index.php?searchindex=Music&searchk=${QUERY}&itempage=${PAGE}"

echo "Searching for: [$QUERY]"
echo "Searching ... [$URL]"

declare -a COVERURLS=(`curl -s "$URL" | grep -Eo "$PATTERN" | sed -E 's/^<a href="(.*)"$/\1/'`)

if [ ${#COVERURLS[@]} -eq 0 ]
then
	echo "Failed to find album art for $1" >&2
	exit 1
fi

echo "Cover URL: [${COVERURLS[$(($INDEX - 1))]}]"
curl -s -o "$IMG" "${COVERURLS[$(($INDEX - 1))]}"
[ $? -ne 0 ] && [ ! -s "$IMG" ] && exit 1

echo "Embedding ... [`stat -c %s $IMG` bytes]"
find "$1" -type f -name '*.mp3' -print0 | xargs -0 -I % -- sh -c \
"eyeD3 -2 --remove-images '%';eyeD3 -2 --add-image='${IMG}:FRONT_COVER' '%'"

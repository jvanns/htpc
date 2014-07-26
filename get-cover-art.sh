#!/bin/bash -e
# get_coverart.sh
#
# This simple script will fetch the cover art for the album information
# provided on the command line. It will then download that cover image,
# and place it into the child directory. The term "album information" is
# really the relative path of the final directory.
#
# get_coverart <relative-path>
# 
# get_coverart Tonic/Lemon Parade
# 
# get_coverart Tonic/Lemon\ Parade
# 
# get_coverart Tonic/Lemon_Parade
#
# find . -type d -exec ./get_coverart "{}" \;

DIR="$1"
ESCAPED="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$DIR")"
URL="http://www.albumart.org/index.php?srchkey=$ESCAPED&itempage=1&newsearch=1&searchindex=Music"

if [ "x$1" = "x" ]
then
	echo "Provide a target album-named directory" >&2
	exit 1
fi

# Skip already processed ones 
if [ -f "$DIR/cover.jpg" ]
then
	echo "$DIR/cover.jpg already exists" >&2
	exit 1
fi

echo "Searching for: [$1]"
echo "Searching ... [$URL]"

COVERURL=`wget -qO - $URL | xmllint --html --xpath  'string(//a[@title="View larger image" and starts-with(@href, "http://ecx.images-amazon")]/@href)' - 2> /dev/null`

echo "Cover URL: [$COVERURL]"
wget "$COVERURL" -O "$DIR/cover.jpg"

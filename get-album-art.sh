#!/bin/bash
#
# This simple script will fetch the cover art for the album information
# provided on the command line. It will then download that cover image,
# and place it into the temporary directory. The term "album information" is
# really the album-named relative path of the current directory.
#

if [ "x$1" = "x" ]
then
	echo "Provide a target album-named directory" >&2
	exit 1
fi

PAGE='http://www.albumart.org/index.php'
ESCAPED="`perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "${1// /+}"`"
URL="${PAGE}?searchkey=$ESCAPED&itempage=1&newsearch=1&searchindex=Music"

echo "Searching for: [$1]"
echo "Searching ... [$URL]"

XMLCMD='xmllint --html --xpath'
AMAZON='http://ecx.images-amazon'
COVERURL=`wget -qO - "$URL" | $XMLCMD \
'string(//a[@title="View larger image" and starts-with(@href, "'$AMAZON'")]/@href)' - 2> /dev/null`

echo "Cover URL: [$COVERURL]"
wget -qO - "$COVERURL" 1> "${TMP}/album-art.jpg"
[ $? -eq 0 ] && [ -s "${TMP}/album-art.jpg" ] && exit 0


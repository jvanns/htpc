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

dpath="$1"
encoded="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$dpath")"

# Skip already processed ones 
if [ -f "$dpath/cover.jpg" ]
then
echo "$dpath/cover.jpg already exists"
exit
fi

echo ""
echo "Searching for: [$1]"
url="http://www.albumart.org/index.php?srchkey=$encoded&itempage=1&newsearch=1&searchindex=Music"
echo "Searching ... [$url]"
coverurl=`wget -qO - $url | xmllint --html --xpath  'string(//a[@title="View larger image" and starts-with(@href, "http://ecx.images-amazon")]/@href)' - 2>/dev/null`
echo "Cover URL: [$coverurl]"
wget "$coverurl" -O "$dpath/cover.jpg"


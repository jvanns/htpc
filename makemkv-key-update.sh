#!/bin/sh

URL='http://www.makemkv.com/forum2/viewtopic.php?f=5&t=1053'
KEY="`lynx -source $URL | grep 'codecontent">' | cut -d \> -f11 | sed 's/<\/div$//'`"

echo "app_Key = \"$KEY\""

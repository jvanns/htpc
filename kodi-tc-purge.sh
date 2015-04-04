#!/bin/bash
#
# This simple script will delete all Kodi texture caches of a specific type
#

# Default parameters
KODI_USER=media # Most have 'xbmc', I chose the more generic 'media'
KODI_MEDIA='music' # Forms part of a LIKE pattern in the SQL below

while getopts 'u:m:h' OPTION; do
	case $OPTION in
	u)
		KODI_USER="$OPTARG"
		;;
	m)
		KODI_MEDIA="$OPTARG"
		;;
	h)
		echo -e "Usage: $0 [options]\nOptions:"
		echo -e "   -h           Help! Print this message then exit"
		echo -e "   -u <user>    An alternative Kodi user to '$KODI_USER'"
		echo -e "   -m <media>   An alternative Kodi media path to '$KODI_MEDIA'"
		exit 0
		;;
	?)
		exit 1
		;;
	esac
done
shift $(($OPTIND - 1))

set -eu

declare -a TOOLS=(sqlite3 xargs rm)
for t in ${TOOLS[@]}
do
	if [ ! -x "`which $t 2> /dev/null`" ]; then
		echo "Required tool '$t' not found or not executable" >&2
		exit 1
	fi
done

locate_texture_db()
{
	ls -tr "${1}/Database/Textures"*.db | tail -n1
}

USERDATA="`getent passwd ${KODI_USER} | cut -d: -f6`/.kodi/userdata/"
if [ ! -d "$USERDATA" ]; then
	echo "'$USERDATA' not a directory or does not exist" >&2
	exit 1
fi

TARGET_DB="`locate_texture_db ${USERDATA}`"
if [ "x$TARGET_DB" = "x" ]; then
	echo "Failed to find the Kodi Texture DB under ${USERDATA}"
	exit 1
fi

if [ ! -w "$TARGET_DB" ]; then
	echo "'$TARGET_DB' not a writable file" >&2
	exit 1
fi

Q1="SELECT cachedurl FROM texture WHERE url LIKE 'image://${KODI_MEDIA}%'"
Q2="DELETE FROM texture WHERE url LIKE 'image://${KODI_MEDIA}%'"

sqlite3 "$TARGET_DB" "$Q1" | xargs -I% -- rm -fv ${USERDATA}/Thumbnails/%
sqlite3 "$TARGET_DB" "$Q2"

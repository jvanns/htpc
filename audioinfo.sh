#!/bin/sh

set -eu

cat <<EOF | mediainfo --Inform='file:///dev/stdin' "$1"
General;%CompleteName%\n
Audio;%Format%,%Language%,%Channels%,%BitDepth%,%BitRate%,%StreamKindID%,%ID%\n
EOF

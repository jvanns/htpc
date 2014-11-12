#!/bin/sh

set -eu

cat <<EOF | mediainfo --Inform='file:///dev/stdin' "$1"
General;%Encoded_Library%,%CompleteName%,
Audio;%Format%,%Language%,%Channels%,%BitDepth%,%BitRate%
EOF

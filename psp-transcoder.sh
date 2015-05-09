#!/bin/bash
#
# Given n video files on the command line, transcode them for a PSP 3000
# device (MP4[AVC, AAC]) in the default or optionally overridden directory.
#

# Default parameters
OUTDIR="`pwd`"
ASPECT='4:3'

ffmpeg_encode()
{
	ffmpeg 	-i "$1" -f psp -threads auto -pass 1 \
		-ac 2 -ar 48000 -b:a 224k \
		-r 30000/1001 -aspect $ASPECT -s 480x272 -b:v 384k -vcodec h264 -subq 6 \
		-level 30 -trellis 0 -refs 2 -bf 8 -b-pyramid none -weightb 0 -mixed-refs 0 \
		-8x8dct 0 -coder ac -y /dev/null && \
	ffmpeg 	-i "$1" -f psp -threads auto -pass 2 \
		-ac 2 -ar 48000 -b:a 224k \
		-r 30000/1001 -aspect $ASPECT -s 480x272 -b:v 384k -vcodec h264 -subq 6 \
		-level 30 -trellis 0 -refs 2 -bf 8 -b-pyramid none -weightb 0 -mixed-refs 0 \
		-8x8dct 0 -coder ac -y "$2"
}

while getopts 'a:o:h' OPTION; do
	case $OPTION in
	a)
		ASPECT="$OPTARG"
		;;
	o)
		OUTDIR="$OPTARG"
		;;
	h)
		echo -e "Usage: $0 [options] <video file,...>\nOptions:"
		echo -e "   -h                 Help! Print this message then exit"
		echo -e "   -a <aspect ratio>  Alternative aspect ratio to $ASPECT"
		echo -e "   -o <output dir>    Alternative output directory to $OUTDIR"
		exit 0
		;;
	?)
		exit 1
		;;
	esac
done
shift $(($OPTIND - 1))

if [ "x$1" = "x" ]; then
	echo "Provide at least 1 input video file" >&2
	exit 1
fi

set -eu

declare -a TOOLS=(ffmpeg)
for t in ${TOOLS[@]}
do
	if [ ! -x "`which $t 2> /dev/null`" ]; then
		echo "Required tool '$t' not found or not executable" >&2
		exit 1
	fi
done

cd /tmp
for f in $@
do
	if [ ! -f "$f" ]; then
		echo "'$f' not a regular file" >&2
		continue
	fi

	name="`basename $f`"
	base="${OUTDIR}/${name%%.*}"

	ffmpeg_encode "$f" "${base}.mp4" 2>&1 | tee "${base}.log"
done

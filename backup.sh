#!/bin/bash

set -eu

DUMMY=''
TARGET=''
NOW=`date +%s`
NAME="`uname -n`"

check_fs() {
	local v=`grep -c " ${1} " /proc/mounts`
	[ $v = "1" ] && return 0 || return 1
}

get_level()
{
	local -r db='/var/lib/dumpdates'
	grep "^${1} " "${db}" | sort -t ' ' -k2 -n | tail -n1 | awk '{print $2}'
}

get_dev()
{
	local -r db='/etc/mtab'
	grep "^/.* ${1} " "${db}" | awk '{print $1}'
}

next_level()
{
	local d=`get_dev "${1}"`
	local -i l=`get_level "${d}"`

	echo $((${l} + 1))
}

backup_system()
{
	local -a sources=('/' '/home')
	local d="${TARGET}/system/`date +%m`"

	mkdir -p "$d" || return 1

	for fs in ${sources[@]}
	do
		name=${fs##*/}
		level=`next_level "${fs}"`
		
		if [ "x$name" = "x" ]; then
			name='root'
		fi
		
		$DUMMY dump -${level} -uj -v \
			-A "${d}/dump-${name}-archive-${level}.log" \
			-f "${d}/dump-${name}-db-${level}.log" "${fs}"
	done
}

backup_data()
{
	local d="${TARGET}/data"
	local -a sources=('/mnt/video' '/mnt/music' '/mnt/photo')

	mkdir -p "$d" || return 1

	for fs in ${sources[@]}
	do
		name=${fs##*/}
		
		if [ "x$name" = "x" ]; then
			name='root'
		fi

		$DUMMY rsync -aqmxh --delete-during -T /tmp -h --progress --stats \
         "${fs}/" "${d}/${name}/"
	done
}

while getopts 'dh' OPTION; do
   case $OPTION in
   d)
      DUMMY=echo
      ;;
   h)
      echo -e "Usage: $0 [options] <device>\nOptions:"
      echo -e "\t-h\tHelp! Print this message then exit"
      echo -e "\t-d\tDummy mode - print, don't execute"
      exit 0
      ;;
   ?)
      exit 1
      ;;
   esac
done
shift $(($OPTIND - 1))

if [ -z "$1" ]; then
   echo "$0: Required device path not provided; try -h" >&2
   exit 1
fi

TARGET="${1}/$NAME"

check_fs "${1}" || exit 1
mkdir -p "${TARGET}/logs" || exit 1

backup_data >> "${TARGET}/logs/${NOW}.log" 2>&1
backup_system >> "${TARGET}/logs/${NOW}.log" 2>&1


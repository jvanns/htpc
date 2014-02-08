#!/bin/bash

set -eu

NOW=`date +%s`
NAME="`uname -n`"
TARGET="${1}/$NAME"

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
		
		dump -${level} -uj -v \
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

		rsync -aqmx --delete-during -T /tmp -h --progress "${fs}" "${d}/${name}"
	done
}

check_fs "${1}" || exit 1
mkdir -p "${TARGET}/logs" || exit 1

backup_data >> "${TARGET}/logs/${NOW}.log" 2>&1
backup_system > "${TARGET}/logs/${NOW}.log" 2>&1


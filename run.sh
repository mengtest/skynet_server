#!/bin/bash

export ROOT=$(cd `dirname $0` ; pwd)
export DAEMON=false

name=$1

if [ $# -lt 1 ]
then
    echo 请输入配置名，如:run.sh login
    exit
fi

shift

while getopts "Dk" arg
do
	case $arg in
		D)
			DAEMON=true
			;;
		k)
			kill `cat $ROOT/pids/$name.pid`
			exit 0;
			;;
	esac
done


$ROOT/3rd/skynet/skynet $ROOT/server_configs/$name.config

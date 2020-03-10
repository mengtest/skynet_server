#!/bin/bash

export ROOT=$(cd `dirname $0` ; pwd)

while getopts "k" arg
do
	case $arg in
		k)
			$ROOT/run.sh db -k
			$ROOT/run.sh login -k
			$ROOT/run.sh game0 -k
			$ROOT/run.sh game1 -k
			exit 0;
			;;
	esac
done

$ROOT/run.sh db -D
$ROOT/run.sh login -D
$ROOT/run.sh game0 -D
$ROOT/run.sh game1 -D
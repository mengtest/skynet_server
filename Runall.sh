#!/bin/bash

export ROOT=$(cd `dirname $0` ; pwd)

while getopts "Dk" arg
do
	case $arg in
		k)
			$ROOT/game-db.sh -k
			$ROOT/login-run.sh -k
			$ROOT/game-run.sh -k
			$ROOT/game-run.1.sh -k
			exit 0;
			;;
	esac
done

$ROOT/game-db.sh -D
$ROOT/login-run.sh -D
$ROOT/game-run.sh -D
$ROOT/game-run.1.sh -D
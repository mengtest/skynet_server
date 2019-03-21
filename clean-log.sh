#!/bin/bash

export ROOT=$(cd `dirname $0` ; pwd)

find $ROOT/robot/run/log -type f ! -name "DUMMY"|xargs rm -f
find $ROOT/server-login/run/log -type f ! -name "DUMMY"|xargs rm -f
find $ROOT/server-game/run/log -type f ! -name "DUMMY"|xargs rm -f
find $ROOT/server-game1/run/log -type f ! -name "DUMMY"|xargs rm -f

find $ROOT/robot/run/log -type d |xargs rmdir -p
find $ROOT/server-login/run/log -type d |xargs rmdir -p
find $ROOT/server-game/run/log -type d |xargs rmdir -p
find $ROOT/server-game1/run/log -type d |xargs rmdir -p
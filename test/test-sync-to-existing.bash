#!/usr/bin/env bash
set -euo pipefail
readonly mydir="$( cd "${BASH_SOURCE[0]%/*}" && pwd )"
source "$mydir/test-base.bash" "$@"
shift || true

alias diffq='diff -q '
assert_diff(){
   assert diff -q test1a/"$1" test1b/"$1"
}


mkdir -p test1a test1b
trap "rm -rf $PWD/test1a $PWD/test1b; #kill 0;" EXIT

echo "Hello World" >test1a/hello_world
autorsync --use-rx test1a localhost:$PWD/test1b --no-initial-tx  & ars_pid=$!
assert kill -0 $ars_pid

echoinfo "Test hello_world was not initially synced to destination"
assert ! test -e test1b/hello_world

## Test SRC synced to DST
touch test1a/touched
echo "I Love World" >test1a/i_love_world
sleep 1.1
assert ! test -f test1b/touched
assert diff -q test1a/touched test1b/test1a/touched

kill $ars_pid
assert diff -q test1a/hello_world test1b/hello_world

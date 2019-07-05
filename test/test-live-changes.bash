#!/usr/bin/env bash
set -euo pipefail
readonly mydir="$( cd "${BASH_SOURCE[0]%/*}" && pwd )"
source "$mydir/test-base.bash" "$@"
shift || true

assert_diff(){
   assert diff -q test1a/"$1" test1b/"$1"
}


mkdir -p test1a test1b
trap "rm -rf $PWD/test1a $PWD/test1b; kill 0;" EXIT
echo "Hello World" >test1a/hello_world
autorsync test1a/ localhost:$PWD/test1b & ars_pid=$!
assert kill -0 $ars_pid
sleep 1.2  ## wait for inital sync

## Test live changes a->b
touch test1a/touched
echo "I Love World" >test1a/i_love_world
sleep 1.1
assert_diff touched
assert_diff i_love_world


## Test live changes b->a
touch test1b/touched-b
echo "I Love World B" >test1a/i_love_world-b
sleep 1.1
assert_diff touched-b
assert_diff i_love_world-b

kill $ars_pid
assert diff -q test1a/hello_world test1b/hello_world

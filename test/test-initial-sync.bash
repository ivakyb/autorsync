#!/usr/bin/env bash
set -euo pipefail
readonly mydir="$( cd "${BASH_SOURCE[0]%/*}" && pwd )"
source "$mydir/test-base.bash" "$@"
shift || true

mkdir -p test1a test1b
clean_up(){ rm -rf $PWD/test1a $PWD/test1b; }

echo "Hello World" >test1a/hello_world
autorsync test1a/ localhost:$PWD/test1b & ars_pid=$!
assert kill -0 $ars_pid
sleep 1
kill $ars_pid || true
assert diff -q test1a/hello_world test1b/hello_world

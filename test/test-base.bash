#!/usr/bin/env bash
set -euo pipefail
readonly md="$( cd "${BASH_SOURCE[0]%/*}" && pwd )"  #"$( dirname $(realpath ${BASH_SOURCE[0]} ) )"
source "$md/../utils.bash"
#source "$(realpath $(dirname "${BASH_SOURCE[0]}"))/../utils.bash"


AUTORSYNC="${1:-$mydir/../autorsync.bash}"
shift || true

assert(){
   eval "$@" || { 
      excod=$?
      fatalerr "Assert FAILED: $@"
      return $excod
   }
}
autorsync(){
   "$AUTORSYNC" "$@"
}

alias diffq='diff -q '

assert_diff(){
   assert diff -q test1a/"$1" test1b/"$1"
}

trap_append clean_up EXIT

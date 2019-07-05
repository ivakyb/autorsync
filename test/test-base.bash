#!/usr/bin/env bash
set -euo pipefail
readonly md="$( cd "${BASH_SOURCE[0]%/*}" && pwd )"  #"$( dirname $(realpath ${BASH_SOURCE[0]} ) )"
source "$md/../utils.bash"
#source "$(realpath $(dirname "${BASH_SOURCE[0]}"))/../utils.bash"


AUTORSYNC="${1:-$mydir/../autorsync.bash}"
shift || true

assert(){
   "$@" || { 
      excod=$?
      fatalerr "Assert FAILED: $@"
      return $excod
   }
}
autorsync(){
   "$AUTORSYNC" "$@"
}

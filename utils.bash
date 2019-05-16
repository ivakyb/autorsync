#!/usr/bin/env bash

## See https://gitlab.com/etde/E1DCS-bin/snippets/1830522 
## DOWNLOAD:
##   curl -L 'https://gitlab.com/snippets/1830548/raw?inline=false' -o utils.bash
## USAGE: 
##   source utils.bash

set -euo pipefail #,errtrace,nounset  # -e == -o errtrace. Also consider to use -ET

var_is_set(){
   declare -rn var=$1
   ! test -z ${var+x}
}
var_is_set_not_empty(){
   declare -rn var=$1
   ! test -z ${var:+x}
}
var_is_unset(){
   declare -rn var=$1
   test -z ${var+x}
}
var_is_unset_or_empty(){
   declare -rn var=$1
   test -z ${var:+x}
}

is_sourced(){
   [[ "${BASH_SOURCE[0]}" != "${0}" ]]
}

if test -t /dev/stdout ;then
   msgcolor=$'\e[1;37m'
   msgnocol=$'\e[0m'
else
   msgcolor=$'\e[1;37m'
   msgnocol=$'\e[0m'
fi
if test -t /dev/stderr ;then
   :;
fi

function colordbg {
   if test -t /dev/stderr ;then
      echo $'\e[0;36m'
   fi
}

function echomsg                  { echo $'\e[1;37m'"$@"$'\e[0m'; }
if var_is_set DEBUG  &&  [[ $DEBUG != 0 ]]  ;then 
   function echodbg  { >/dev/stderr echo $'\e[0;36m'"DBG  $@"$'\e[0m'; }
   function catdbg   { >/dev/stderr echo $'\e[0;36m'; cat $@; echo $'\e[0m'; }
else
   function echodbg  { :; }  ## do nothing
fi
if var_is_unset NOINFO  ||  [[ $NOWARN == 0 ]]  ;then 
   function echoinfo { >/dev/stderr echo $'\e[1;37m'"INFO $@"$'\e[0m'; }
else
   function echoinfo { :; }  ## do nothing
fi
if var_is_unset NOWARN  ||  [[ $NOWARN == 0 ]]  ;then 
   function echowarn { >/dev/stderr echo $'\e[0;33m'"WARN $@"$'\e[0m'; }
else
   function echowarn { :; }  ## do nothing
fi
function echoerr  { >/dev/stderr echo $'\e[0;31m'"ERR  $@"$'\e[0m'; }
function fatalerr { echoerr "$@"; false; }
alias die=fatalerr

function OnError {  caller | { read line file; echoerr "in $file:$line" >&2; };  }
trap OnError ERR

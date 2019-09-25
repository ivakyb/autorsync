#!/usr/bin/env bash

## See https://gitlab.com/etde/E1DCS-bin/snippets/1830522 
## DOWNLOAD:
##   curl -L 'https://gitlab.com/snippets/1830548/raw?inline=false' -o utils.bash
## USAGE: 
##   source utils.bash

set -eETuo errexit -o nounset -o pipefail #-o errtrace -o functrace
shopt -s expand_aliases lastpipe #gnu_errfmt globstar huponexit inherit_errexit localvar_inherit

#[[ ${BASH_SOURCE:-} != "" ]] && {
#   BASH_SOURCE=( EMPTY_BASH_SOURCE )
#}

#export PS4='+ $(date "+%F_%T") ${FUNCNAME[0]:-NOFUNC}() $BASH_SOURCE:${BASH_LINENO[0]} +  '  ## From https://stackoverflow.com/a/22617858
export PS4=$'+\e[33m ${BASH_SOURCE[0]:-nofile}:${BASH_LINENO[0]:-noline} ${FUNCNAME[0]:-nofunc}()\e[0m  '

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

[[ ${BASH_SOURCE:-} != "" ]] && SRCDIR="$(realpath $(dirname "${BASH_SOURCE[-1]}"))"

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
   #shopt -s extdebug
   function echodbg  { >/dev/stderr echo $'\e[0;36m'"DBG  $@"$'\e[0m'; }
   function catdbg   { >/dev/stderr echo $'\e[0;36m'; cat $@; echo $'\e[0m'; }
else
   function echodbg  { :; }  ## do nothing
fi
if var_is_unset NOINFO  ||  [[ $NOWARN == 0 ]]  ;then 
   function echoinfo { >/dev/stderr echo $'\e[0;37m'"INFO $@"$'\e[0m'; }
else
   function echoinfo { :; }  ## do nothing
fi
if var_is_unset NOWARN  ||  [[ $NOWARN == 0 ]]  ;then 
   function echowarn { >/dev/stderr echo $'\e[0;33m'"WARN $@"$'\e[0m'; }
else
   function echowarn { :; }  ## do nothing
fi
function echoerr  { >/dev/stderr echo $'\e[0;31m'"ERR  $@"$'\e[0m'; }
function fatalerr { 
   echoerr "$@"
   stacktrace2 2
   exit 1
}
alias die=fatalerr

function stacktrace { 
   local i=1
   while caller $i | read line func file; do 
      echodbg "[$i] $file:$line $func()"
      ((i++))
   done
}
function stacktrace2 {
   local i=${1:-1} size=${#BASH_SOURCE[@]}
   ((i<size)) && echodbg "STACKTRACE"
   for ((; i < size-1; i++)) ;do  ## -1 to exclude main()
      ((frame=${#BASH_SOURCE[@]}-i-2 ))
      echodbg "[$frame] ${BASH_SOURCE[$i]:-}:${BASH_LINENO[$i]} ${FUNCNAME[$i+1]}()"
   done
}

## Execute only for debug purposes command
if var_is_set DEBUG  &&  [[ $DEBUG != 0 ]]  ;then 
   function debug  { "$@" | catdbg; }
else
   function debug  { : "$@"; }  ## do nothing
fi

## Do not overwrite but append.
function trap_append {
   local handler="$1"
   shift
   for sigspec in "$@" ;do
      local old_handler="$( trap -p "$sigspec" | perl -e "$/ = undef; <STDIN> =~ /'(.*?)'/s; print \$1;" )"
      handler="$old_handler"$'\n'"$handler"
      trap "$handler" "$sigspec"
   done
}

array(){
   array=$1; shift; "$@"
}
contains_element(){
   declare -n __arr=$array
   local elem
   for elem in "${__arr[@]}" ;do [[ "$elem" == "$1" ]] && return 0; done
   return 1
}

## Usage for_each var_name in array_name do 
for_each_in_var(){
   declare -rn _a=$1
   shift
   for elem in ${!_a[@]} ;do
      eval "$@" $elem
   done
}

kill_sure(){
   kill -TERM "$@" &>/dev/null ||  return 0   ## Already dead
   sleep 0.3
   if kill -0 "$@" &>/dev/null ;then
      echowarn "Force kill $1"
      kill -9 "$@" 2>&-
   fi
}

#function OnError {  caller | { read line file; echoerr "in $file:$line" >&2; };  }
OnError(){ stacktrace; }
trap OnError ERR

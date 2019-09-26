#!/usr/bin/env bash
set -euo pipefail
source "$(realpath $(dirname "${BASH_SOURCE[0]}"))/utils.bash"

while (( $# > 0 ))
do
   case "$1" in
      --autorsync=*)
         AUTORSYNC="${1#*=}"
         ;;
      *)
         testcases_to_run+=("$1")
         ;;
   esac
   shift
done
AUTORSYNC=${AUTORSYNC:=$SRCDIR/autorsync.bash}

assert(){
   eval "$@" || { 
      excod=$?
      echoerr "Assert FAILED in ${BASH_SOURCE[0]:-}:${BASH_LINENO[0]} ${FUNCNAME[1]:-nofunc}()  $@"
      stacktrace2 #2 2
      exit 1
   }
}
assert_warn(){
   eval "$@" || { 
      excod=$?
      echowarn "Assert FAILED: $@"
      [[ $- != *e* ]] && return 0 || return $excod
   }
}

autorsync(){
   "$AUTORSYNC" "$@"
}

alias diffq='diff -q '

assert_file_contents_are_same(){
   assert diff -q "$1" "$2"
}

#trap_append 'set -x' EXIT


declare -A TestcasesDescriptions TestcasesStatuses
SUCCEEDED=0
FAILED=0
SKIPPED=0
DECLARED=0

declare_test(){ local name="$1" description="${2:-}" declared=declared
   ## Assert arrays of Testcases does not already contain $name
   assert ! array Testcases contains_element $name
   Testcases+=(             "$name" )   
   TestcasesDescriptions+=( [$name]="$description" )
   status $name declared  #TestcasesStatuses+=(     [$name]=$declared )
#   declare -gA Testcase_$name=( [name]=$name [description]="$description" [status]=$declared [stdout]= [stderr]= )
}

status(){ local name=$1 status=$2 status_full="${@:2}"
   case $status in
      declared)  ((DECLARED++))  ||true ;;
      skipped)   ((SKIPPED++))   ||true ;;
      succeeded) ((SUCCEEDED++)) ||true ;;
      failed)    ((FAILED++))    ||true ;;
   esac
   TestcasesStatuses+=( [$name]="$status_full" )
#   Testcase_$name+=( [status]="$status" )
}
status_get(){ local name=$1
   echo ${TestcasesStatuses[$1]}
}

run_test(){ local testname=$1; 
#assert_warn (( $#==1 ))
   #assert function is declared
   echomsg --- $testname \""${TestcasesDescriptions[$testname]}"\"
   status $testname started
   SKIPFILE=$(mktemp)
   if (
      #status $testname running
      workdir=$(mktemp -d)
      trap_append "rm -r $workdir" EXIT
      cd $workdir
      $testname
   );then
      if [[ $(cat $SKIPFILE) = $testname ]]; then 
         status $testname skipped
         echo "--- $testname "$'\e[1;33m'"SKIPPED"$'\e[0m'
      else
         status $testname succeeded
         echo "--- $testname "$'\e[1;32m'"SUCCEEDED"$'\e[0m'
      fi
   else
      status $testname failed $?
      #TestcasesStatuses+=( [$testname]=$? )
      echo "--- $testname "$'\e[1;31m'"FAILED"$'\e[0m'
   fi
   rm $SKIPFILE
}

show_testcases(){
   for testname in ${Testcases[@]} ;do
      echomsg --- $testname \""${TestcasesDescriptions[$testname]}"\"
   done
}

execute_testcases(){
   #if [[ "${testcases_to_run[@]}" ]] ;then
   #   
   #else
   #   declare -n testcases_to_run=Testcases
   #fi
   #for testname in ${testcases_to_run[@]} ;do
   #   run_test $testname
   #done
   #for testname in ${Testcases[@]} ;do
   #   if [[ "$(status_get $testname)" == "declared" ]];then
   #      status $testname skipped
   #   fi
   #done
   
   if [[ "${testcases_to_run[@]}" ]] ;then
      for testname in ${Testcases[@]} ;do
         if array testcases_to_run contains_element $testname ;then
            run_test $testname
         else
            status $testname skipped
         fi
      done
   else
      for testname in ${Testcases[@]} ;do
         run_test $testname
      done
   fi
   ## ToDo fatalerr "no such testcase"
}

start_autorsync(){
   assert var_is_unset_or_empty autorsync_pid
   autorsync "$@"  & autorsync_pid=$!
   sleep 0.2 && assert kill -0 $autorsync_pid 2>&-
   trap_append "kill_sure $autorsync_pid; unset autorsync_pid" exit
   #echoinfo "AutoRSync started with PID $autorsync_pid"
}

alias skip='echo "$testname">$SKIPFILE; return 0'

report_results(){
   echo -e "\e[31mFAILED \e[1;31m$FAILED\e[0m, \e[32mSUCCEEDED \e[1;32m$SUCCEEDED\e[0m, \e[33mSKIPPED \e[1;33m$SKIPPED\e[0m"
   if ((FAILED<=127)) ;then
      EXIT_CODE=$FAILED
   else 
      EXIT_CODE=127
   fi
}

## ToDo
## Ability to stop on first error  --first-error
## Ability for parallel running    --parallel=`nproc`|-j5

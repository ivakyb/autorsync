#!/usr/bin/env bash
set -euo pipefail
source "$(realpath $(dirname "${BASH_SOURCE[0]}"))/utils.bash"

## First letter in uppercase means this is a main function for user code
## Should be used after all tests were declared
Testing(){
   execute_testcases
   report_results
   exit $EXIT_CODE
}

while (( $# > 0 ))
do
   case "$1" in
      list|show|show_testcases)
         Testing(){
            show_testcases
            exit
         } ;;
      all)
         ALL=y
         ;;
      *)
         testcases_to_run+=("$1")
         ;;
   esac
   shift
done
var_is_set ALL && unset testcases_to_run

assert(){
   eval "$@" || { 
      excod=$?
      #echoerr "Assert FAILED in ${BASH_SOURCE[0]:-}:${BASH_LINENO[0]} ${FUNCNAME[1]:-nofunc}()  $@"
      #echoerr "Assert FAILED in ${BASH_SOURCE[1]:-}:${BASH_LINENO[0]} ${FUNCNAME[1]:-nofunc}()  $@"
      caller | { read line file; echoerr "Assert FAILED in $file:line  $@" ;}
      #stacktrace #2 2
      exit 1
   }
}

assert_warn(){
   eval "$@" || { 
      excod=$?
      echowarn "Assert FAILED: $@"
      [[ $- != *e* ]] && return 0 || return $excod  ## If errexit
   }
}

assert_file_contents_are_same(){
   diff -q "$1" "$2" || { 
      excod=$?
      echoerr "Assert FAILED in ${BASH_SOURCE[1]:-}:${BASH_LINENO[0]} ${FUNCNAME[1]:-nofunc}()  $@"
      stacktrace
      exit 1
   }
}

#trap_append 'set -x' EXIT


declare -A TestcasesDescriptions TestcasesStatuses
declare -i SUCCEEDED=0 FAILED=0 SKIPPED=0 DECLARED=0

declare_test(){ local name="$1" description="${2:-}" declared=declared
   ## Assert arrays of Testcases does not already contain $name
   assert ! array Testcases contains_element $name
   Testcases+=(             "$name" )   
   TestcasesDescriptions+=( [$name]="$description" )
   status $name declared  #TestcasesStatuses+=(     [$name]=$declared )
#   declare -gA Testcase_$name=( [name]=$name [description]="$description" [status]=$declared [stdout]= [stderr]= )
   if declare -F $name >/dev/null ;then
      readonly -f $name
   fi
}

status(){ local name=$1 status=$2 status_full="${@:2}"
   case $status in
      declared)  DECLARED+=1  ;; #((DECLARED++))  ||true ;;
      skipped)   SKIPPED+=1   ;; #((SKIPPED++))   ||true ;;
      succeeded) SUCCEEDED+=1 ;; #((SUCCEEDED++)) ||true ;;
      failed)    FAILED+=1    ;; #((FAILED++))    ||true ;;
      #*) fatalerr "Unexpected value status=$status"
   esac
   TestcasesStatuses+=( [$name]="$status_full" )
#   Testcase_$name+=( [status]="$status_full" )
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
   set +e; (
      set -euo pipefail
      #status $testname running
      workdir=$(mktemp -d)
      trap "cd; rm -r $workdir" EXIT
      cd $workdir
      $testname
   ); local status=$?; set -e
   if ((status==0)) ;then
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

alias skip='echo "$testname">$SKIPFILE; return 0'
alias SKIP=skip

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

#!/usr/bin/env bash
set -euo pipefail
DEBUG=1
source "$(realpath $(dirname "${BASH_SOURCE[0]}"))/utils.bash"

AUTORSYNC="${1:-$SRCDIR/autorsync.bash}"
shift || true

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
SUCCEDED=0
FAILED=0
SKIPPED=0

declare_test(){ local name="$1" description="${2:-}" declared=declared
   ## Assert arrays of Testcases does not already contain $name
   assert ! array Testcases contains_element $name
   Testcases+=(             "$name" )   
   TestcasesDescriptions+=( [$name]="$description" )
   TestcasesStatuses+=(     [$name]=$declared )
#   declare -gA Testcase_$name=( [name]=$name [description]="$description" [status]=$declared [stdout]= [stderr]= )
}

status(){ local name=$1 status="$2"
   TestcasesStatuses+=( [$name]="$status" )
#   Testcase_$name+=( [status]="$status" )
}

run_test(){ local testname=$1; 
#assert_warn (( $#==1 ))
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
         ((SKIPPED++)) ||true
         status $testname skipped
         echo "--- $testname "$'\e[1;37m'"SKIPPED"$'\e[0m'
      else
         ((SUCCEDED++)) ||true
         status $testname succeded
         echo "--- $testname "$'\e[1;32m'"SUCCEEDED"$'\e[0m'
      fi
   else
      ((FAILED++)) ||true
      status $testname "failed $?"
      #TestcasesStatuses+=( [$testname]=$? )
      echo "--- $testname "$'\e[1;31m'"FAILED"$'\e[0m'
   fi
   rm $SKIPFILE
}

for_each_testcase(){
   for testname in ${Testcases[@]} ;do
      eval "$@" $testname
   done
}
show_testcases(){
   for testname in ${Testcases[@]} ;do
      echomsg --- $testname \""${TestcasesDescriptions[$testname]}"\"
   done
}
execute_testcases(){
   for testname in ${Testcases[@]} ;do
      run_test $testname
   done
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
   echo -e "\e[31mFAILED \e[1;31m$FAILED\e[0m, \e[32mSUCCEDED \e[1;32m$SUCCEDED\e[0m, \e[37mSKIPPED \e[1;37m$SKIPPED\e[0m"
   #echo "Failed: ${TestcasesFailed}"
   #echo "Skipped: ${TestcasesSkiped}"
}


#############################################
## Test 1
## Initial sync
#############################################
declare_test initial_sync "Initial sync"
function initial_sync {
   mkdir tx_local rx_remote
   echo "Hello World" >tx_local/hello_world
   autorsync tx_local/ localhost:$PWD/rx_remote & ars_pid=$!
   assert kill -0 $ars_pid  ## are you alive?
   sleep 1
   kill $ars_pid 2>&- #|| true
   assert_file_contents_are_same tx_local/hello_world rx_remote/hello_world
}

#############################################
## Test 2
## Live changes on local side
#############################################
declare_test live_changes "Live changes on local side should be synchronized to remote side."
function live_changes {
   mkdir -p test1a test1b
   #clean_up(){ rm -rf $PWD/test1a $PWD/test1b; }  ## PWD will be removed

   assert_diff(){
      assert diff -q test1a/"$1" test1b/"$1"
   }

   echo "Hello World" >test1a/hello_world
   start_autorsync --use-rx test1a/ localhost:$PWD/test1b
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
   debug tree test1a test1b
   assert_diff touched-b
   assert_diff i_love_world-b
   
   assert diff -q test1a/hello_world test1b/hello_world
}


#############################################
## Test 3
## Synchronize to existing directory
#############################################
declare_test sync-to-existing "Synchronize files to existing directory."
function sync-to-existing {
   skip
   mkdir -p tx_local rx_remote/tx_local

   echo "Hello World" >tx_local/hello_world
   
   start_autorsync --rx --no-initial-tx tx_local localhost:$PWD/rx_remote/
   sleep 1.2  ## Wait for possible initial sync, but it should not
   
   echoinfo "Test hello_world was not initially synced to destination"
   assert ! test -e rx_remote/hello_world

   ## Test SRC synced to DST
   touch tx_local/touched
   echo "I Love World" >tx_local/i_love_world
   sleep 2.1
   debug tree tx_local rx_remote
   assert ! test -e rx_remote/touched
   assert diff -q tx_local/touched rx_remote/tx_local/touched

   pkill -P $autorsync_pid  ## https://stackoverflow.com/questions/2618403/how-to-kill-all-subprocesses-of-shell#17615178
   assert diff -q tx_local/hello_world rx_remote/hello_world
   
debug jobs -l
#   wait
}

#############################################
## Test 4
## Synchronize to existing directory
## If SRC ends with / sync files in it, else sync SRC itself.
#############################################
declare_test initial_sync_with_slash "Synchronize files to existing directory."
function initial_sync_with_slash {
   mkdir -p tx_local rx_remote
   echo "Hello World" >tx_local/hello_world
   
   start_autorsync tx_local localhost:$PWD/rx_remote
   sleep 1.2
   
   echoinfo "Test hello_world was initially synced to destination"
debug tree tx_local rx_remote
   assert test -e rx_remote/tx_local/hello_world
   pkill -P $autorsync_pid  ## https://stackoverflow.com/questions/2618403/how-to-kill-all-subprocesses-of-shell#17615178
   assert diff -q tx_local/hello_world rx_remote/tx_local/hello_world
   
#echodbg ----- jobs; debug jobs -l
#echodbg ----- pgrep; debug pgrep -P $$
#echodbg ----- pstree; debug pstree $$
}

#############################################
## Test 5. TODO
## Synchronize to existing directory. Live sync
## If SRC ends with / sync files in it, else sync SRC itself.
#############################################



#############################################
## Execute Testcases
#############################################
execute_testcases
#run_test initial_sync
#run_test live_changes
#run_test sync-to-existing
#run_test initial_sync_with_slash

## ToDo
## Ability to stop on first error  --first-error
## Ability for parallel running    --parallel=`nproc`|-j5
report_results

if ((FAILED<=127)) ;then
   exit $FAILED
else 
   exit 127
fi

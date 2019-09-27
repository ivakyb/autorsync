#!/usr/bin/env bash
set -euo pipefail
DEBUG=1

ARGS=()
while (( $# > 0 ))
do
   case "$1" in
      --autorsync=*|autorsync=*)  ##ToDo move this to test-autorsync.bash
         AUTORSYNC="${1#*=}"
         ;;
      *)
         ARGS+=("$1")
   esac
   shift
done

source "$(realpath $(dirname "${BASH_SOURCE[0]}"))/testing.bash" "${ARGS[@]}"

AUTORSYNC=${AUTORSYNC:=$SRCDIR/autorsync.bash}


## PREREQUISITES
## 1. ssh must be configured to be able `ssh localhost` without typing passwords
## 2. 


start_autorsync(){
   assert var_is_unset_or_empty autorsync_pid
   autorsync "$@"  & autorsync_pid=$!
   sleep 0.2 && assert kill -0 $autorsync_pid 2>&-
   trap_append "pstree $autorsync_pid; kill_sure $autorsync_pid; unset autorsync_pid" exit
   #echoinfo "AutoRSync started with PID $autorsync_pid"
}

autorsync(){
   "$AUTORSYNC" "$@"  ||
   {
      ## If autorsync was terminated with SIGTERM do not report an error
      declare -i status=$? SIGTERM=15
      (($status==SIGTERM)) && status=0
      return $status
   }
}


#############################################
## Test 1
## Initial sync
#############################################
declare_test initial_sync "Initial sync"
function initial_sync {
   mkdir tx_local rx_remote
   echo "Hello World" >tx_local/hello_world
   
   autorsync --initial-tx-only tx_local localhost:$PWD/rx_remote  ## SRC ends without slash '/'
   assert_file_contents_are_same tx_local/hello_world rx_remote/tx_local/hello_world
   
   rm -rf rx_remote/*
   
   autorsync --initial-tx-only tx_local/ localhost:$PWD/rx_remote
   assert_file_contents_are_same tx_local/hello_world rx_remote/hello_world
}
readonly -f initial_sync

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
readonly -f live_changes

#############################################
## Test 3
## Synchronize to existing directory
#############################################
declare_test sync_to_existing "Synchronize files to existing directory."
function sync_to_existing {
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
readonly sync_to_existing

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
readonly -f initial_sync_with_slash

#############################################
## Test 5. TODO
## Synchronize to existing directory. Live sync
## If SRC ends with / sync files in it, else sync SRC itself.
#############################################
declare_test live_sync_with_slash "Live synchronize files to existing directory."
function live_sync_with_slash {
   mkdir -p tx_local rx_remote
   
   start_autorsync --no-initial-tx tx_local localhost:$PWD/rx_remote
   sleep 1.1
   
   echo "Hello World" >tx_local/hello_world
   sleep 1.1
debug tree tx_local rx_remote
   assert diff -q tx_local/hello_world rx_remote/tx_local/hello_world
   
   pkill -P $autorsync_pid  ## https://stackoverflow.com/questions/2618403/how-to-kill-all-subprocesses-of-shell#17615178
}
readonly -f live_sync_with_slash

#############################################
## Test 6.
## RSync SRC/ and SRC - with or without trailing slash
## If SRC ends with / sync contained files, else sync SRC directory itself.
#############################################
declare_test rsync_with_slash "Live synchronize files to existing directory."
function rsync_with_slash {
   mkdir -p tx_local rx_remote
   
   echo "Hello World" >tx_local/hello_world
   rsync -a tx_local rx_remote
debug tree tx_local rx_remote
   assert diff -q tx_local/hello_world rx_remote/tx_local/hello_world   
   
   rm -rf rx_remote/*
   rsync -a tx_local/ rx_remote
debug tree tx_local rx_remote
   assert diff -q tx_local/hello_world rx_remote/hello_world   
}
readonly -f rsync_with_slash

#############################################
## Test 7
## Stop process
#############################################
declare_test stop_process "Stop process"
function stop_process {
   SKIP  ## Look at last line of function
   mkdir tx_local rx_remote
   echo "Hello World" >tx_local/hello_world
   autorsync tx_local/ localhost:$PWD/rx_remote & ars_pid=$!
   sleep 0.2 && assert kill -0 $ars_pid  ## are you alive?
   sleep 1
   kill $ars_pid 2>&-  ## Kills only parent process but not its childs. FIXME
}
readonly -f stop_process


#############################################
## Execute Testcases
#############################################
Testing

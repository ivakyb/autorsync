#!/usr/bin/env bash
set -euo pipefail
DEBUG=1
VERSION=000
## On MacOS need:
##   brew install coreutils && ln -s greadlink /usr/local/bin/readlink  &&   ln -s gmktemp /usr/local/bin/mktemp
readonly mydir="$( dirname $(readlink -f ${BASH_SOURCE[0]} ) )"

source $mydir/utils.bash
#source $mydir/environment

if test `uname` == Darwin ;then
   alias sed=gsed
   alias find=gfind
   alias date=gdate
   alias cp=gcp
   alias mv=gmv
   alias ls=gls
fi

#REMOTE_PATH="rsync://localhost:10873/root/"
unset SRC
unset DST
USE_TX=y
USE_RX=y

## Parse options
while (( $# > 0 ))
do
   case "$1" in
      --initial-exclude=*) ;;
      --exclude=*)  ;;
      --tx|--use-tx)
         USE_TX=y
         ;;
      --rx|--use-rx)
         USE_RX=y
         ;;
      --no-tx|--notx)
         unset USE_TX
         ;;
      --no-rx|--norx)
         unset USE_RX
         ;;
      --only-tx|--tx-only)
         USE_TX=y
         unset USE_RX
         ;;
      --only-rx|--rx-only)
         USE_RX=y
         unset USE_TX
         ;;
      --version)
         echo "$VERSION"
         exit
         ;;
      --*) echoerr "Unknown option: $1" ;;
      *) if var_is_unset_or_empty SRC ;then
            SRC+=("$1") 
         elif var_is_unset_or_empty DST ;then
            DST="$1"
         else
            #SRC+=("$DST")
            #DST="$1"
            echowarn "SRC and DST already set. Ignoring $1"
         fi
   esac
   shift
done
## Assert
var_is_set_not_empty SRC || fatalerr "Source is not set" 
var_is_set_not_empty DST || fatalerr "Destionation is not set" 


## Initial sync
##!!!!!!!!!! FIXME CANNOT SYNC TO EXISTING FOLDER
##!!!!!!!!! IF DST IS DIR AND EXIST DST for this stage must go up one layer
function initial_tx
{
   echoinfo "Begin initial sync to container. Nothing will be deleted, only copy and update."
   rsync -aR --info=progress2  \
      --exclude-from=<( cat <<END
   .Spotlight-V100
   .TemporaryItems
   .Trashes
   .fseventsd
   .DS_Store
   build-*
END
   ) \
      "$SRC" "$DST"  &&
      echoinfo "Initial sync to container done."  ||
      echowarn "Initial sync finished with errors/warnings."
}

function fswatch_cmd
{
   ## See https://github.com/emcrisostomo/fswatch/issues/212#issuecomment-473369919 for full list of events
   EndOfTransmittion=$'\x04'
   fswatch "$1" --batch-marker=$'\x04' \
         --latency ${period:=1} \
         --recursive \
         --event Created --event Updated --event Removed --event Renamed --event AttributeModified --event OwnerModified \
         --exclude '.*/index.lock' --exclude '\.idea/.*' --exclude '.*___jb_old___' --exclude '.*___jb_tmp___' \
         --exclude '\.DS_Store' --exclude '\.git/FETCH_HEAD' --exclude '\.rsync\.temp/.*'
         #--event" "{Created,Updated,Removed,Renamed,AttributeModified} \   
         #--event IsFile --event IsDir --event IsSymLink \
         #--event-flags \
}

function normalize_path
{
   local rp="$1"; shift
   sed -e"s#$rp/##g" -e"s#^$rp\$##g" "$@"  ## linux's inotify can respond with PWD folder, which we will not use
}

function rsync_cmd
{
   ## ToDo OPTIMIZATION if DST is ssh-url, start rsyncd on destination host and user rsync:// for often rsync requests. Will be faster because does not need open ssh connection every time.
   ff=$(mktemp) && trap "rm $ff" exit
   while read -d $'\x04' ;do
      echodbg $'\n'"$(test "$1" == "$SRC" && echo "L==>R" || echo "L<==R")$REPLY"
      echo "$REPLY" >$ff #| cut -d' ' -f1 >$ff
      normalize_path "$NORMALIZE_PATH" -i $ff
      rsync -v --archive --relative --delete --delete-missing-args --info=progress2 --files-from=$ff --temp-dir=.rsync.temp --exclude='.rsync.temp/*' "$@"  ||  true
   done
}

function rsync_tx
{
   mkdir -p $SRC/.rsync.temp
   fswatch_cmd "$SRC" | 
      NORMALIZE_PATH="$(realpath "$SRC")" \
      rsync_cmd "$SRC" "$DST"
}

function rsync_rx
{
   DST_HOST=$(cut -d: -f1 <<<$DST)
   DST_PATH=$(cut -d: -f2 <<<$DST)
   ssh $DST_HOST bash -x - <<END  | NORMALIZE_PATH="$(ssh "$DST_HOST" realpath "$DST_PATH")" rsync_cmd "$DST" "$SRC"
      set -euo pipefail
      mkdir -p "$DST_PATH"/.rsync.temp
      #trap "rm -rf $DST_PATH/.rsync.temp" exit
      period=$period
      ulimit -n 10000
      `declare -f fswatch_cmd echoerr echowarn echodbg`
      echowarn XXX $PWD
      fswatch_cmd "$DST_PATH"
END
}

## Sync on change
period=1
#echoinfo "Startning sync_on_change with period=$period"

if var_is_set USE_TX ;then
   initial_tx
   echoinfo "Starting rsync_tx"
   rsync_tx  & pid_tx=$!
   echoinfo "pid_rsync_tx $pid_tx"
fi

if var_is_set USE_RX ;then
   echoinfo "Starting rsync_rx"
   rsync_rx  & pid_rx=$!
   echoinfo "pid_rsync_rx $pid_rx"
fi


wait
echoinfo DDDDOOOOMMMEEE

### Wait for jobs exit, if interrupted try normally close them, if they fail to close during 2 seconds, force kill.
#wait || kill $(jobs -p)
#sleep 0.3
#JOBS="$(jobs -p)"
#if test "$JOBS" ;then
#   sleep 1.7
#   JOBS="$(jobs -p)"
#   test "$JOBS" && kill -9 "$JOBS"  ## Force kill if did not clone
#fi


## KNOWN ISSUES
## fswatch on MacOS does not detect deleted folder (CHECK)
## may need to set max number of open file descriptors ulimit -n 10000
## fswatch is not a good solution for linux due to Error: Event queue overflow. and long delays. Try inotify-hookable or inotifywait
## NEED periodic full update

#!/usr/bin/env bash
## Author Ivan Kuvaldin aka "kyb"
## Distributed under MIT License, https://opensource.org/licenses/MIT
## Project page https://gitlab.com/kyb/autorsync

set -euo pipefail
shopt -u failglob
shopt -s lastpipe huponexit #inherit_errexit
DEBUG={DEBUG:-1}

VERSION=000
NPM_VERSION=0.0.0

## KNOWN ISSUES
## * fswatch on MacOS does not detect deleted folder (CHECK)
## * may need to set max number of open file descriptors ulimit -n 1170
## * fswatch is not a good solution for linux due to Error: Event queue overflow. and long delays. Try inotify-hookable or inotifywait
## * NEED periodic full update
## * Works only with remote DST
## * It's a question: should we remove .rsync.temp?
## * Cannot trap exit via ssh to remove .rsync.temp
## * Somehow fswatch_cmd "$DST_PATH" on remote host keeps running after stop of autorsync.
## * There is a problem in Docker containers on Mac to deliver inotify events to fswatch and inotify-tools. So for Docker on Mac container use --no-rx or --tx-only

## TODO
## * --help
## * --install and --install-symlink as they are in git-rev-label
## * --initial-tx-delete-missing
## * --cleanup-temp
## * Allow more than one SRC
## * For two side sync it is required to distinguish updates made by autorsync and updates made by others. To suppress cyclic updates.
## * OPTIMIZATION if DST is ssh-url, start rsyncd on destination host and user rsync:// for often rsync requests. Will be faster because does not need to open ssh connection every time.
## * OPTIMIZATION Consider locate .rsync-temp in RAM, at least for low size files.

function darwin_aliases {
   if test `uname` == Darwin ;then
      alias sed=gsed
      alias find=gfind
      alias date=gdate
      alias cp=gcp
      alias mv=gmv
      alias ls=gls
      alias mktemp=gmktemp
      alias readlink=greadlink
   fi
}
darwin_aliases

## On MacOS need:
##   brew install coreutils
readonly mydir="$( dirname $(readlink -f ${BASH_SOURCE[0]} ) )"
##ToDo may be use `realpath`

source $mydir/utils.bash

trap_append 'echoinfo autorsync: TERMINATED' TERM
trap_append 'echoinfo autorsync: INTERRUPTED' INT
trap_append 'echoinfo autorsync: HANG UP' HUP
trap_append 'ps=$(jobs -p); ${ps:+ kill $ps} || true;' EXIT
#trap "kill -hup 0" hup

unset SRC
unset DST
USE_INITIAL_TX=y
USE_TX=y
USE_RX=
RSYNC_PATH=  ## From man rsync: --rsync-path=PROGRAM    specify the rsync to run on remote machine
RSH=
SSH=ssh

readonly EXCLUDES_LIST=$(mktemp)
trap_append "echodbg 'Removing EXCLUDES_LIST'; rm -f $EXCLUDES_LIST" EXIT

## Parse options
while (( $# > 0 ))
do
   case "$1" in
      --help)
         echowarn "Option --help is under construction!"
         exit
         ;;
      --period=*)
         period="${1#--period=}"
         ;;
      --exclude=*)
         echo "${1#--exclude=}" >>$EXCLUDES_LIST
         USE_DEFAULT_EXCLUDES_LIST=${USE_DEFAULT_EXCLUDES_LIST:=n}  ## Set to 'n' if was not already set
         ;;
      --exclude-from=*)
         cat "${1#--exclude-from=}" >>$EXCLUDES_LIST
         USE_DEFAULT_EXCLUDES_LIST=${USE_DEFAULT_EXCLUDES_LIST:=n}  ## Set to 'n' if was not already set
         ;;
      --exclude-defaults)  ## Normally DEFAULT_EXCLUDES_LIST is not used when --excludes and/or --excludes-from options are set. This brings excludes together.
         USE_DEFAULT_EXCLUDES_LIST=y
         ;;
      --no-exclude-defaults)  ## Overrides --exclude-defaults to disable its behavior
         USE_DEFAULT_EXCLUDES_LIST=n
         ;;
      --show-exclude-defaults|--show-default-exclude|--show-default-excludes)
         USE_DEFAULT_EXCLUDES_LIST=y
         SHOW_EXCLUDE_DEFAULTS=y
         break #STOP_PARSE_OPTIONS
         ;;
      --no-initial-tx|--noinitialtx|--disable-initial-tx|--noitx)
         unset USE_INITIAL_TX
         ;;
      --initial-tx|--enable-initial-tx|--use-initial-tx)
         USE_INITIAL_TX=y
         ;;
      --initial-tx-only)
         USE_INITIAL_TX=y
         unset USE_TX USE_RX
         ;;
      --initial-tx-delete-missing)
         echowarn "Option --initial-tx-delete-missing is under construction!"
         ;;
      --tx|--use-tx)
         USE_TX=y
         ;;
      --rx|--use-rx)
         USE_RX=y
         ;;
      --rxtx|--txrx)
         USE_TX=y
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
      --cleanup-temp)
         ## Remove .rsync.temp before exit
         echowarn "Option --cleanup-temp is under construction!"
         ;;
      --no-remove-rsync-temp)
         ## Do not .rsync.temp before exit
         echowarn "Option --no-remove-rsync-temp is under construction!"
         ;;
      --rsh=*)
         RSH="${1#*=}"
         SSH="${1#*=}"
         ;;
      --rsync-path=*)
         RSYNC_PATH="${1#*=}"
         ;;
      --version)
         echo "$VERSION"
         exit
         ;;
      --npm-version|--version-npm)
         echo "$NPM_VERSION"
         exit
         ;;
      --install)
         echowarn "Option --install is under construction! Refer to git-rev-label for impl."
         ;;
      --install-symlink)
         echowarn "Option --install-symlink is under construction! Refer to git-rev-label for impl."
         ;;
      --install-symlink)
         echowarn "Option --install-symlink is under construction! Refer to git-rev-label for impl."
         ;;
      -x) set -x ;;
      +x) set +x ;;
      -*|--*) fatalerr "Unknown option: $1" ;;
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

USE_DEFAULT_EXCLUDES_LIST=${USE_DEFAULT_EXCLUDES_LIST:=y}  ## if unset or empty, set to default value 'y'
if test $USE_DEFAULT_EXCLUDES_LIST = y ;then
   cat >>$EXCLUDES_LIST <<END
.fseventsd
.rsync.temp/
.git/FETCH_HEAD
.git/index.lock
.git/modules/*/index.lock
.DS_Store
.Spotlight-V100
.TemporaryItemss
.Trashes
build-*
*___jb_old___
*___jb_tmp___
.idea/
END
fi

if var_is_set_not_empty SHOW_EXCLUDE_DEFAULTS && test $SHOW_EXCLUDE_DEFAULTS = y ;then
   cat $EXCLUDES_LIST
   exit
fi

## Assert
var_is_set_not_empty SRC || fatalerr "Source is not set" 
var_is_set_not_empty DST || fatalerr "Destination is not set" 
## If SRC ends with slash '/' sync folder contents without the folder itself
## ToDo: consider combinations DST/SRC/file/directory

function excludes_for_fswatch 
{
   sed $EXCLUDES_LIST -f <(cat <<'END'
      /^#/d
      s#\.#\\\.#g
      s#\*#.*#g
      s#\?#.?#g
      s#^#--exclude #g
END
)
}

## Initial sync
function initial_tx
{
   echoinfo "Begin initial sync to container. Nothing will be deleted, only copy and update."
   #local DST_PATH=$(ssh "$DST_HOST" bash -c "test; test -d \"$DST_PATH\" && echo \"$DST_PATH/../$(basename "$SRC")\" || echo \"$DST_PATH\"")
   ## If $SRC ends with / sync files in it, else sync SRC itself.
   if test "${SRC: -1}" = /  &&  test -d "$SRC" ;then
      local FIND_FILES=y
      #echoinfo "${FIND_FILES+ --files-from=<(find "$SRC" | sed -E 's#'"$SRC"'/?##g')}"
      #find "$SRC" | sed -E 's#'"$SRC"'/?##g'
   fi
   #mkdir -p .rsync.temp  #mktemp -d 
   $SSH $DST_HOST mkdir -p "$DST_PATH"/.rsync.temp #bash -xc "test -d '$DST_PATH' && mkdir -p '$DST_PATH'/.rsync.temp || mkdir -p '$DST_PATH'.rsync.temp"
   if rsync --archive --info=progress2  \
         --temp-dir=.rsync.temp  \
         --exclude-from=$EXCLUDES_LIST \
         ${RSYNC_PATH:+"--rsync-path=$RSYNC_PATH"} \
         ${RSH:+"--rsh=$RSH"} \
         "$SRC" "$DST" \
         #${FIND_FILES:+ --files-from=<(find "$SRC" | sed -E 's#'"$SRC"'/?##g')}
         #--relative 
   then echoinfo "Initial sync to container done."
   else echowarn "Initial sync finished with errors/warnings."
   fi
}

function fswatch_cmd
{
   ## See https://github.com/emcrisostomo/fswatch/issues/212#issuecomment-473369919 for full list of events
   EndOfTransmittion=$'\x04'
   fswatch "$1" --batch-marker=$'\x04' \
         ${period:+ --latency $period} \
         --recursive \
         --event Created --event Updated --event Removed --event Renamed --event AttributeModified --event OwnerModified \
         $(excludes_for_fswatch)
         ##--exclude '.*/index.lock' --exclude '\.idea/.*' --exclude '.*___jb_old___' --exclude '.*___jb_tmp___' \
         ##--exclude '\.DS_Store' --exclude '\.git/FETCH_HEAD' --exclude '\.rsync\.temp/.*'
         #--event" "{Created,Updated,Removed,Renamed,AttributeModified} \   
         #--event IsFile --event IsDir --event IsSymLink \
         #--event-flags \
         # $(excludes_for_fswatch)
}

function normalize_path
{
   local rp="$1"; shift
   sed -e"s#$rp/##g" -e"s#^$rp\$##g" "$@"  ## linux's inotify can respond with PWD folder, which we will not use
}

function rsync_cmd
{
   ## ToDo OPTIMIZATION if DST is ssh-url, start rsyncd on destination host and user rsync:// for often rsync requests. Will be faster because does not need to open ssh connection every time.
   ff=$(mktemp) && 
      trap_append "echodbg 'Clean up rsync_cmd. Removing ff $ff'; rm $ff" EXIT
   while read -d $'\x04' ;do
      echodbg "$(test "$src" == "$SRC" && echo "-->" || echo "<--") " #$REPLY"
      echo "$REPLY" >$ff
      normalize_path "$NORMALIZE_PATH" -i $ff
      if rsync --archive --relative --delete --delete-missing-args  \
            --info=progress2 --files-from=$ff  \
            --temp-dir=.rsync.temp --exclude='.rsync.temp/*' \
            "$src" "$dst" \
            ${RSYNC_PATH:+"--rsync-path=$RSYNC_PATH"} \
            ${RSH:+"--rsh=$RSH"} \
            "$@" \
            #${FIND_FILES:+ --files-from=<(find "$1" | sed -E 's#'"$1"'/?##g')}
      then :
      else echowarn "Failed to sync: $(cat $ff)"
      fi
   done
}

function rsync_tx
{
   $SSH $DST_HOST mkdir -p "$DST_PATH"/.rsync.temp
   trap_append "echodbg 'Cleanup rsync_tx. Removing ssh://\"$DST_PATH/.rsync.temp\"'; $SSH $DST_HOST rm -rf \"$DST_PATH/.rsync.temp\"" EXIT
 
   NORMALIZE_PATH="$(realpath "$SRC")"
   echodbg NORMALIZE_PATH $NORMALIZE_PATH
   
   fswatch_cmd "$SRC" | 
      NORMALIZE_PATH="$(realpath "$SRC")" \
      src="$SRC" dst="$DST" rsync_cmd
}

function rsync_rx
{
   ## ToDo Create rsync.temp on local side
   # if test -d $SRC
   # then local tempdir="$SRC/.rsync.temp"
   # else local tempdir="${SRC%/*}/.rsync.temp"
   # fi
   # mkdir -p "$tempdir"
   # trap_append "echodbg 'Cleanup rsync_tx. Removing \"$tempdir\"'; rm -rf \"$tempdir\"" EXIT

   remote_command() {
      set -euo pipefail
      trap OnError ERR
      darwin_aliases
      #mkdir -p "$DST_PATH"/.rsync.temp
      ulimit -n 10000
      fswatch_cmd "$DST_PATH"
   }
   $SSH $DST_HOST ${REMOTE_PATH:+$REMOTE_PATH/}bash -<<END  | NORMALIZE_PATH="$($SSH "$DST_HOST" ${REMOTE_PATH:+$REMOTE_PATH/}realpath "$DST_PATH")" src="$DST" dst="$SRC" rsync_cmd
      set -euo pipefail
      if test `uname` == Darwin ;then export PATH="/usr/local/bin:$PATH" ;fi
      $(cat $mydir/utils.bash)
      DST_PATH="$DST_PATH"  period=$period  DEBUG=$DEBUG
      EXCLUDES_LIST=\$(mktemp)
      echo "$(cat $EXCLUDES_LIST)" >\$EXCLUDES_LIST
      $(declare -f)
      remote_command
END
   unset -f remote_command
}


DST_HOST="${DST%:*}"  #$(cut -d: -f1 <<<$DST)
DST_PATH="${DST#*:}"  #$(cut -d: -f2 <<<$DST)
REMOTE_UNAME="$($SSH $DST_HOST uname)"
var_is_unset_or_empty REMOTE_PATH && test $REMOTE_UNAME = Darwin && REMOTE_PATH=/usr/local/bin
var_is_unset_or_empty RSYNC_PATH  && test $REMOTE_UNAME = Darwin && RSYNC_PATH="${REMOTE_PATH:+$REMOTE_PATH/}rsync"
if var_is_set_not_empty USE_TX && var_is_set_not_empty USE_RX
then fatalerr "Two side sync is not stable!" ;fi
#test $(uname -s) == Darwin && period=0.5 || period=1

if var_is_set USE_INITIAL_TX ;then
   echoinfo "Begin initial_tx"
   initial_tx
   echoinfo "Done initial_tx"
fi

if ! test "${SRC: -1}" = /  || ! test -d "$SRC"
then  DST+="/`basename "$SRC"`/"
      DST_PATH="${DST#*:}"
fi

if var_is_set_not_empty USE_TX ;then
   echoinfo "Starting rsync_tx"
   rsync_tx  & pid_tx=$!
   sleep 0.2 && kill -0 $pid_tx 2>&- ||  fatalerr "rsync_tx $pid_tx failed to start"  ## Check process is running successfully
   echoinfo "pid_rsync_tx $pid_tx"
   #trap_append "kill $pid_tx" EXIT
fi

if var_is_set_not_empty USE_RX ;then
   echoinfo "Starting rsync_rx"
   rsync_rx  & pid_rx=$!
   sleep 0.2 && kill -0 $pid_rx 2>&- ||  fatalerr "rsync_rx $pid_rx failed to start" ## Check process is running successfully
   echoinfo "pid_rsync_rx $pid_rx"
   #trap_append "kill $pid_rx" EXIT
fi

## Fix problem: subprocesses do not exit with main
#echodbg "============ jobs -l =============="
#debug jobs -l
#echodbg "============ pstree \$\$ =============="
#debug pstree $$
wait || true
echodbg "---------------------------------------------"
echoinfo "autorsync done."

### Wait for jobs exit, if interrupted try normally close them, if they fail to close during 2 seconds, force kill.
#wait || kill $(jobs -p)
#sleep 0.3
#JOBS="$(jobs -p)"
#if test "$JOBS" ;then
#   sleep 1.7
#   JOBS="$(jobs -p)"
#   test "$JOBS" && kill -9 "$JOBS"  ## Force kill if did not clone
#fi

#!/usr/bin/env bash

## =====================
## Create one executable file without dependancies to source/include files.
## =====================

set -euo pipefail
if test `uname` == Darwin ;then
   alias sed=gsed
   alias grep=ggrep
   alias mktemp=gmktemp
fi
#FILE=autorsync
#grep -P '(?<=^source\s).*' $FILE
#sed -E "s#^source (.*)#$(cat $1)#" autorsync > rsyncdouble
tdir=$(mktemp -d)
trap "rm -rf $tdir" exit
split -p '^source \$mydir' -a1 autorsync.bash $tdir/autorsync_
cat $tdir/autorsync_a <(echo -e '\n####_utils.bash_####') utils.bash <(echo -e '\n####_EOF_utils.bash_####\n\n') <(tail -n+2 $tdir/autorsync_b) >autorsync
chmod +x autorsync

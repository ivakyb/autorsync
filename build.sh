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

## Only for BSD systems because of 'split'
#tdir=$(mktemp -d)
#trap "rm -rf $tdir" exit
#split -p '^source \$mydir' -a1 autorsync.bash $tdir/autorsync_
#cat $tdir/autorsync_a <(echo -e '\n####_utils.bash_####') utils.bash <(echo -e '\n####_EOF_utils.bash_####\n\n') <(tail -n+2 $tdir/autorsync_b) >autorsync

sed -e '/^source \$mydir/ { 
                           r utils.bash
                           d
                        }' autorsync.bash >autorsync

chmod +x autorsync

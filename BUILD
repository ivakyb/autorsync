#!/usr/bin/env bash
set -eo pipefail

BUILD_ID=${CI_PIPELINE_IID}
if test -x ./autorsync ;then 
   BUILD_ID=$(./autorsync --version | sed -E 's#.*-b([0-9]+).*#\1#')
   let BUILD_ID++
fi
BUILD_ID=${BUILD_ID:=1}  ## fall back to 1

sed -f ./build.sed autorsync.bash >autorsync
sed -i "s#VERSION=000#VERSION=$(git rev-label --format='$refname-c$count-g$short'-b$BUILD_ID\$_dirty )#" autorsync
chmod +x autorsync

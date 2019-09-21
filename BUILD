#!/usr/bin/env bash
set -eo pipefail

BUILD_ID=${CI_PIPELINE_IID}
if test -x ./autorsync  &&  ./autorsync --version ;then 
   BUILD_ID=$(./autorsync --version | sed -E 's#.*-b([0-9]+).*#\1#')
   let BUILD_ID++
fi
BUILD_ID=${BUILD_ID:=1}  ## fall back to 1

sed autorsync.bash >autorsync -f-<<'END'
{
   /^source \$mydir/ {
      a
      a ### BEGIN utils.bash ###
      r utils.bash
      a ### END utils.bash ###
      a 
      d
   }
}
END
VERSION="$(git rev-label --format='$refname-c$count-g$short'-b$BUILD_ID\$_dirty )"
sed -i "s#VERSION=000#VERSION=$VERSION#" autorsync

MAJ_VER=0; if test "$CI_COMMIT_REF_NAME" = master ;then MAJ_VER=1; fi 
#NPM_VERSION="$(echo $VERSION | sed -nE 's#.*c([0-9]+)-g(.[0-9a-f]+)-b([0-9]+).*#'$MAJ_VER'.\1.\3#p' )"
NPM_VERSION="$(git rev-label --format=$MAJ_VER.'$count'.$BUILD_ID )"
sed -i "s#NPM_VERSION=0.0.0#NPM_VERSION=$NPM_VERSION#" autorsync

chmod +x autorsync

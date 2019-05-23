#!/usr/bin/env sed autorsync.bash -f

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
[![](https://gitlab.com/kyb/autorsync/badges/master/pipeline.svg)](https://gitlab.com/kyb/autorsync/pipelines?scope=branches)

# AutoRSync
Two-side file syncronization utility written in bash using [rsync](https://rsync.samba.org/) and [fswatch](https://github.com/emcrisostomo/fswatch).
Able to monitor changes and synchronize files between two hosts.

### Why
Since Docker volumes have a very poor performance on MacOS (about 45-60 times slower than native), 
user may want to look for a fast alternative.

AutoRSync was developed to give ability to edit files on Mac and keep updated mirror in Docker container.
Comparing to docker-volumes autorsync scheme consumes two times more space, but half-hundred times faster. 

## Prerequisties
*  `bash` version 4 or later, 
*  [`rsync`](https://rsync.samba.org/) version 3 or later,
*  [`fswatch`](https://github.com/emcrisostomo/fswatch), 
*  `ssh`, 
*  `perl` *(todo rm dependancy)*.
*  `pgrep` and `pkill` from package psmisc

```sh
brew install bash coreutils rsync fswatch perl findutils gnu-sed
```
*To run [./test-autorsync.bash](./test-autorsync.bash) also need `brew install tree pstree`*

## Usage
The syntax similar to rsync
```
autorsync /local/path/ remote_host:/target/path/
```
*ToDo write here more detailed examples and explanation*

Trailing slash in SRC is important. See https://stackoverflow.com/questions/20300971/rsync-copy-directory-contents-but-not-directory-itself

## Installation

### Manual

    ( cd /usr/local/bin && curl -LO https://gitlab.com/kyb/autorsync/raw/artifacts/master/autorsync && chmod +x autorsync ; ) 

or use [download link](https://gitlab.com/kyb/autorsync/raw/artifacts/master/autorsync)

### NPM (node package manager)

    npm install --global autorsync
    
or the same *npm i -g autorsync*

## ToDo
[Issues/Boards](https://gitlab.com/kyb/autorsync/-/boards)

## Alternatives
* docker-sync
* Docker NFS volume (still slow)
* use SAMBA (not fast enough to build Linux)

---
**Inspired by** article [How to speed up shared file access in Docker for Mac][2] by Sebastian Barthel

  [2]: https://medium.freecodecamp.org/speed-up-file-access-in-docker-for-mac-fbeee65d0ee7


## [License](LICENSE)
MIT License
Copyright (c) 2019 Ivan Kuvaldin aka "kyb"

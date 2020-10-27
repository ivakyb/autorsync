[![](https://gitlab.com/kyb/autorsync/badges/master/pipeline.svg)](https://gitlab.com/kyb/autorsync/pipelines?scope=branches)

# AutoRSync [![GitLab](https://img.shields.io/badge/gitlab-main-blue?style=flat-square&logo=gitlab&color=2B5)](https://gitlab.com/kyb/autorsync) [![GitHub](https://img.shields.io/badge/GitHub-mirror-blue?style=flat-square&logo=GitHub&color=78A)](https://github.com/ivakyb/autorsync)

AutoRSync is a live file syncronization utility written in bash using [rsync](https://rsync.samba.org/) and [fswatch](https://github.com/emcrisostomo/fswatch).
It is able to monitor changes and synchronize files rapidly from one host to another.  
Briefly, this Bash script is a conglomerate of `fswatch|rsync`.

### Why
This utility was created as alternative to Docker volumes because of very poor performance on MacOS. 
It is very useful when editing code on host but build and run inside a Docker container.  
On MacOS and Windows Docker volumes are very slow because of virtualization.
Writing files in docker container back to host's filesystem gives huge performance penalty – about 45-60 times slower than native. 

AutoRSync gives ability to edit files on one host and keep updated mirror in another one.
Comparing to docker-volumes autorsync scheme consumes two times more space, but half-hundred times faster. 


## Usage
The syntax is similar to `rsync`
```
autorsync /local/path/ remote_host:/target/path/
```
Trailing slash in SRC is important. See [stackoverflow.com](https://stackoverflow.com/questions/20300971/rsync-copy-directory-contents-but-not-directory-itself).

*ToDo write here more detailed examples and explanation*

See also [usecase-docker.md](usecase-docker.md) about how to configure Docker container.

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
  [3]: https://www.jeffgeerling.com/blog/2020/revisiting-docker-macs-performance-nfs-volumes


## [License](LICENSE)
MIT License  
Copyright (c) 2019 Ivan Kuvaldin aka "kyb"

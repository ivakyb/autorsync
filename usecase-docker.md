## Configure continious syncronization to Docker container
###  prerequisite
It is expected you already have [SSH key](https://www.ssh.com/ssh/keygen/).

Run Docker container in background

    docker run -itd --rm -p127.0.0.1:10022:22 --name ubu1 --hostname ubu1 ubuntu

Add `authorized_keys` to the container

    docker exec ubu1 mkdir -p /root/.ssh/
    docker cp ~/.ssh/id_rsa ubu1:/root/.ssh/authorized_keys

Run `autorsync`

    autorsync $PWD --rsh='ssh -p10022' root@localhost:$PWD


_P.S. I wrote that from a memory, did not check, something could be missed.._

## Configure continious syncronization to Docker container

Run Docker container in background

    docker run -itd -p127.0.0.1:30022:22 -p127.0.0.1:30873:873 --name ubu1 --hostname ubu1 ubuntu

Append your host public key to container's `authorized_keys`. 
This file must be owned by user and mode be 600 `-rw-------`  
It is expected you already have [SSH key](https://www.ssh.com/ssh/keygen/).

    docker exec ubu1 mkdir -p /root/.ssh/
    docker exec ubu1 bash -c "echo $(cat ~/.ssh/id_rsa.pub) >> /root/.ssh/authorized_keys"

Run `autorsync`

    autorsync $PWD --rsh='ssh -p30022' root@localhost:$PWD


###  Troubleshoting

1. Assert sshd is running

       docker exec ubu1 /usr/sbin/sshd
       
   Logs in foreground could help better
   
       docker exec -it ubu1 /usr/sbin/sshd -d

2. Check connection

       ssh -Tnvvp30022 root@localhost

3. chmod and chown for `authorized_keys` in docker

       chown root:root /root/.ssh/authorized_keys
       chmod 600       /root/.ssh/authorized_keys

       
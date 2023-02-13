#!/bin/bash

set_requirement(){
    apt-get install supervisor -y
}

install_supervisor_ini(){
    mkdir -p /etc/supervisor/conf.d
    cat > /etc/supervisor/conf.d/static-ipsec-nat-t.conf << EOF
[program:decapudp]
command = /opt/static-ipsec-nat-t/decapudp 1100
directory = /opt/static-ipsec-nat-t
autostart=true
autorestart=true
user = root
startsecs = 3
redirect_stderr = true
stdout_logfile_maxbytes = 50MB
stdout_logfile_backups = 10
stdout_logfile = /var/log/decapudp.log
[program:static-ipsec-nat-t]
command = bash /opt/static-ipsec-nat-t/static-ipsec-nat-t.sh --start
stop-command = sh /opt/static-ipsec-nat-t/static-ipsec-nat-t.sh --stop
directory = /opt/static-ipsec-nat-t
autostart=true
autorestart=true
user = root
startsecs = 3
redirect_stderr = true
stdout_logfile_maxbytes = 50MB
stdout_logfile_backups = 10
stdout_logfile = /var/log/static-ipsec-nat-t.log
EOF
echo "install /etc/supervisor/conf.d/static-ipsec-nat-t.conf"
echo "if you are using a low version, you maybe need to copy the configuration to supervisord.conf"
}

install_config_file_temp(){
    mkdir -p /opt/static-ipsec-nat-t/conf.d/
    cat > /opt/static-ipsec-nat-t/temp.conf << EOF
ori_local_public_ip=
nat_local_public_ip=
local_private_ip=
spi_id=0xc0666a70
auth_sha256=0x8896ab8654cd9875e214a978bd31209f
enc_aes=0xea89273861739abc9e0d527ad98462108365289dcb1a6738
remote_public_ip=
remote_private_ip=
ori_local_port=1100
nat_local_port=1100
remote_port=1100
local_default_if=
remote_default_if=
remote_ssh_user=
remote_ssh_port=
EOF
echo "install /opt/static-ipsec-nat-t/temp.conf"
}

install_logrotate_conf(){
    mkdir -p /etc/logrotate.d/
    cat > /etc/logrotate.d/static-ipsec-nat-t << EOF
/var/log/decapudp.log
{ 
    missingok
    notifempty
    sharedscripts
    delaycompress
    create 0644 root root 
        minsize 5M
    rotate 5
    postrotate
    endscript
}
/var/log/static-ipsec-nat-t.log
{ 
    missingok
    notifempty
    sharedscripts
    delaycompress
    create 0644 root root 
        minsize 5M
    rotate 5
    postrotate
    endscript
}
EOF
echo "install /etc/logrotate.d/static-ipsec-nat-t"
}

main(){
    set_requirement
    install_supervisor_ini
    install_config_file_temp
    install_logrotate_conf
    echo """
    decapudp.c can be compile with command:
    gcc decapudp.c -o decapudp
    
    this is very usefull when the pre-compile decapudp can be use !!!

    please make sure the route to <remote private ip> will be route to the internet gateway
    or the packet will not be encrypt

    please make sure the remote machine's firewall allow port 1100 (default udp port, you can change if you know what to do)

    decapudp on remote machine need to be start first before transfer traffic

    run:
    ssh-keygen
    ssh-copy-id <remote_ssh_user>@<remote_public_ip> -p <remote_ssh_port> to authorize this machein
    to login to remote machine

    install successfully, please edit ./temp.conf, and copyt it to conf.d/filename.conf
    and you can rename it if you want

    supervisorctl start static-ipsec-nat-t to start
"""
}

main $*
#!/bin/bash

set_requirement(){
    apt-get install supervisor -y
}

install_supervisor_ini(){
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
command = sh /opt/static-ipsec-nat-t/static-ipsec-nat-t.sh --start
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
}

install_config_file_temp(){
    cat > /opt/static-ipsec-nat-t/conf.d/temp.conf << EOF
ori_local_public_ip=
nat_local_public_ip=
local_private_ip=
spi_id=
auth_sha256=
enc_aes=
remote_public_ip=
remote_private_ip=
ori_local_port= #默认是1100
nat_local_port= #默认是1100
remote_port= #默认是1100
local_default_if=
remote_default_if=
remote_ssh_user=
remote_ssh_port=
EOF
echo "install /opt/static-ipsec-nat-t/conf.d/temp.conf"
}

main(){
    set_requirement
    install_supervisor_ini
    install_config_file_temp
    echo "install successfully, please edit conf.d/temp.conf, and you can rename it if you want"
    echo "supervisorctl start static-ipsec-nat-t to start"
}

main $*
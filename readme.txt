# 在<path/conf.d/local-to-peer.conf>中对以下变量进行定义

在conf.d中的*.conf定义
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

# supervisord管理decapudp

# systemctl管理

# 用法
usage(){
    echo """
    ./$0 --start
    ./$0 --stop
    ./$0 --restart
    ./$0 --dpd
    """
    exit 0

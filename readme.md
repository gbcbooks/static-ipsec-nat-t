# requirement
    conntrack-tools
    decapudp.c 负责解包/封装esp over udp


# 配置文件
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
    [program:decapudp]
    command = /opt/decapudp/decapudp 1100
    directory = /opt/decapudp
    autostart=true
    autorestart=true
    user = root
    startsecs = 3
    redirect_stderr = true
    stdout_logfile_maxbytes = 50MB
    stdout_logfile_backups = 10
    stdout_logfile = /var/log/decapudp.log

# systemctl管理

# 用法
## static-ipsec-nat-t.sh
    usage(){
        echo """
        ./$0 --start
        ./$0 --stop
        ./$0 --restart
        ./$0 --dpd
        """
        exit 0
    test
## decapudp.c
    编译
    gcc decapudp.c -o decapudp


## 感谢

    https://zhuanlan.zhihu.com/p/21884303
    http://techblog.newsnow.co.uk/2011/11/simple-udp-esp-encapsulation-nat-t-for.html
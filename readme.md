# requirement
    conntrack-tools
    decapudp.c 负责解包/封装esp over udp

# 获取
## 获取
    mkdir /opt/static-ipsec-nat-t
    git clone https://github.com/gbcbooks/static-ipsec-nat-t.git "/opt/static-ipsec-nat-t"
## 更新
    cd /opt/static-ipsec-nat-t
    git pull

# 关于安装
    sh install

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
    可以添加到supervisord.conf或独立的*.ini中
    
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

# 关于logrotate
## /etc/logrotate.d/static-ipsec-nat-t
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
## supervisorctl 
    supervisorctl start static-ipsec-nat-t
## decapudp
### 编译
    gcc decapudp.c -o decapudp
### 启动
    /opt/decapudp/decapudp 1100

# 缺点(待改进)
    如果NAT后端有多个节点同时发起建隧道请求，则服务端会有多个NAT后的UDP端口，
    此时会有一定的概率无法把每个UDP端口对应一一对应上会话，在ip x s和ip x p时，就会有混乱的情况出现

# 感谢
    https://www.sobyte.net/post/2022-10/ipsec-ip-xfrm/
    https://zhuanlan.zhihu.com/p/21884303
    http://techblog.newsnow.co.uk/2011/11/simple-udp-esp-encapsulation-nat-t-for.html
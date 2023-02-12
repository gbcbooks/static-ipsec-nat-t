#!/bin/bash

# 在conf.d中的*.conf定义
# ori_local_public_ip=
# nat_local_public_ip=
# local_private_ip=
# spi_id=
# auth_sha256=
# enc_aes=
# remote_public_ip=
# remote_private_ip=
# ori_local_port= #默认是1100
# nat_local_port= #默认是1100
# remote_port= #默认是1100
# local_default_if=
# remote_default_if=
# remote_ssh_user=
# remote_ssh_port=


STATICIPSECDIR=/opt/static-ipsec-nat-t
mkdir -p ${STATICIPSECDIR}/cache
mkdir -p ${STATICIPSECDIR}/conf.d

usage(){
    echo """
    ./$0 --start # restart and keepalive
    ./$0 --stop
    ./$0 --restart
    ./$0 --dpd
    """
    exit 0
}

read_conf(){
    CONFIG=$1
    CONFIG_FILE_NAME=${CONFIG##*/}
    ori_local_public_ip=$(awk -F ' *= *' '$1=="ori_local_public_ip"{print $2}' "${CONFIG}")
    nat_local_public_ip=$(awk -F ' *= *' '$1=="nat_local_public_ip"{print $2}' "${CONFIG}")
    local_private_ip=$(awk -F ' *= *' '$1=="local_private_ip"{print $2}' "${CONFIG}")
    spi_id=$(awk -F ' *= *' '$1=="spi_id"{print $2}' "${CONFIG}")
    auth_sha256=$(awk -F ' *= *' '$1=="auth_sha256"{print $2}' "${CONFIG}")
    enc_aes=$(awk -F ' *= *' '$1=="enc_aes"{print $2}' "${CONFIG}")
    remote_public_ip=$(awk -F ' *= *' '$1=="remote_public_ip"{print $2}' "${CONFIG}")
    remote_private_ip=$(awk -F ' *= *' '$1=="remote_private_ip"{print $2}' "${CONFIG}")
    ori_local_port=$(awk -F ' *= *' '$1=="ori_local_port"{print $2}' "${CONFIG}")
    nat_local_port=$(awk -F ' *= *' '$1=="nat_local_port"{print $2}' "${CONFIG}")
    remote_port=$(awk -F ' *= *' '$1=="remote_port"{print $2}' "${CONFIG}")
    local_default_if=$(awk -F ' *= *' '$1=="local_default_if"{print $2}' "${CONFIG}")
    remote_default_if=$(awk -F ' *= *' '$1=="remote_default_if"{print $2}' "${CONFIG}")
    remote_ssh_user=$(awk -F ' *= *' '$1=="remote_ssh_user"{print $2}' "${CONFIG}")
    remote_ssh_port=$(awk -F ' *= *' '$1=="remote_ssh_port"{print $2}' "${CONFIG}")
}

local_del_tunnel(){
    sudo /sbin/ip xfrm state del src ${ori_local_public_ip} dst ${remote_public_ip} proto esp spi ${spi_id}
    sudo /sbin/ip xfrm state del src ${remote_public_ip} dst ${ori_local_public_ip} proto esp spi ${spi_id}
    sudo /sbin/ip xfrm policy del src ${remote_private_ip} dst ${local_private_ip} dir in ptype main
    sudo /sbin/ip xfrm policy del src ${local_private_ip} dst ${remote_private_ip} dir out ptype main
}

local_add_tunnel(){
    sudo /sbin/ip xfrm state add src ${ori_local_public_ip} dst ${remote_public_ip} proto esp spi ${spi_id} reqid ${spi_id} mode tunnel auth sha256 ${auth_sha256} enc aes ${enc_aes} encap espinudp-nonike ${ori_local_port} ${remote_port} 0.0.0.0
    sudo /sbin/ip xfrm state add src ${remote_public_ip} dst ${ori_local_public_ip} proto esp spi ${spi_id} reqid ${spi_id} mode tunnel auth sha256 ${auth_sha256} enc aes ${enc_aes} encap espinudp-nonike ${remote_port} ${ori_local_port} 0.0.0.0
    sudo /sbin/ip xfrm policy add src ${remote_private_ip} dst ${local_private_ip} dir in ptype main tmpl src ${remote_public_ip} dst ${ori_local_public_ip} proto esp reqid ${spi_id} mode tunnel
    sudo /sbin/ip xfrm policy add src ${local_private_ip} dst ${remote_private_ip} dir out ptype main tmpl src ${ori_local_public_ip} dst ${remote_public_ip} proto esp reqid ${spi_id} mode tunnel
}

remote_del_tunnel(){
    nat_local_public_ip=$(cat ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_nat_local_public_ip)
    if [ ! -z ${nat_local_public_ip} ];then
        ssh ${remote_ssh_user}@${remote_public_ip} -p ${remote_ssh_port} /bin/bash << EOF
        sudo /sbin/ip xfrm state del src ${nat_local_public_ip} dst ${remote_public_ip} proto esp spi ${spi_id}
        sudo /sbin/ip xfrm state del src ${remote_public_ip} dst ${nat_local_public_ip} proto esp spi ${spi_id}
        sudo /sbin/ip xfrm policy del src ${remote_private_ip} dst ${local_private_ip} dir out ptype main
        sudo /sbin/ip xfrm policy del src ${local_private_ip} dst ${remote_private_ip} dir in ptype main
EOF
    else
        echo "nat_local_public_ip not FOUND, remote_del_tunnel EXIT"
    fi
}

remote_add_tunnel_via_ssh(){
    ssh ${remote_ssh_user}@${remote_public_ip} -p ${remote_ssh_port} /bin/bash << EOF
    sudo /sbin/ip xfrm state del src ${nat_local_public_ip} dst ${remote_public_ip} proto esp spi ${spi_id}
    sudo /sbin/ip xfrm state del src ${remote_public_ip} dst ${nat_local_public_ip} proto esp spi ${spi_id}
    sudo /sbin/ip xfrm policy del src ${remote_private_ip} dst ${local_private_ip} dir in ptype main
    sudo /sbin/ip xfrm policy del src ${local_private_ip} dst ${remote_private_ip} dir out ptype main

    sudo /sbin/ip xfrm state add src ${nat_local_public_ip} dst ${remote_public_ip} proto esp spi ${spi_id} reqid ${spi_id} \
    mode tunnel auth sha256 ${auth_sha256} enc aes ${enc_aes} encap espinudp-nonike ${nat_local_port} ${remote_port} 0.0.0.0 \
    || echo "add state failed !!!"
    
    sudo /sbin/ip xfrm state add src ${remote_public_ip} dst ${nat_local_public_ip} proto esp spi ${spi_id} reqid ${spi_id} \
    mode tunnel auth sha256 ${auth_sha256} enc aes ${enc_aes} encap espinudp-nonike ${remote_port} ${nat_local_port} 0.0.0.0 \
    || echo "add state failed !!!"
    
    sudo /sbin/ip xfrm policy add src ${remote_private_ip} dst ${local_private_ip} dir out ptype main \
    tmpl src ${remote_public_ip} dst ${nat_local_public_ip} proto esp reqid ${spi_id} mode tunnel \
    || echo "add policy failed !!!"

    sudo /sbin/ip xfrm policy add src ${local_private_ip} dst ${remote_private_ip} dir in ptype main \
    tmpl src ${nat_local_public_ip} dst ${remote_public_ip} proto esp reqid ${spi_id} mode tunnel \
    || echo "add policy failed !!!"
EOF
}

update_nat_argument(){
    conntrack_result=$(ssh ${remote_ssh_user}@${remote_public_ip} -p ${remote_ssh_port} /bin/bash << EOF
    sudo /usr/sbin/conntrack -L -p udp | grep dport=${remote_port}
EOF
)
echo ${conntrack_result}

nat_local_public_ip=$(echo ${conntrack_result} \
| grep -E "17 [0-9]{1,10} src=([0-9]{1,3}\.){1,3}[0-9]{1,3} dst=${remote_public_ip} sport=[0-9]{1,5} dport=${remote_port}" \
| grep -oE "src=([0-9]{1,3}\.){1,3}[0-9]{1,3}" | grep -v "${remote_public_ip}" | sed "s/src=//"
)
echo "nat_local_public_ip=${nat_local_public_ip}"
echo "${nat_local_public_ip}" > ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_nat_local_public_ip

nat_local_port=$(echo ${conntrack_result} \
| grep -E "src=${nat_local_public_ip} dst=${remote_public_ip} sport=[0-9]{1,5} dport=${remote_port}" \
| grep -oE "sport=[0-9]{1,5}" | grep -v "sport=${remote_port}" | sed "s/sport=//" | tail -1)

echo "nat_local_port=${nat_local_port}"
echo "${nat_local_port}" > ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_nat_local_port
}

probe_session(){
    ping -I ${local_private_ip} ${remote_private_ip} -c 2 -i 0.2 -W 5
}

dpd_keepalive(){
    ping -I ${local_private_ip} ${remote_private_ip} -c 2 -i 0.2 -W 5 && return 0 || return 1
}

remote_add_tunnel(){
    probe_session
    update_nat_argument
    remote_add_tunnel_via_ssh
}

main(){
    case $1 in
        --start)
        while true
        do
            for CONFIG in $(ls ${STATICIPSECDIR}/conf.d/*.conf)
            do
                read_conf ${CONFIG}
                while ! dpd_keepalive
                do
                    echo "clear tunnel session and negotiate"
                    local_del_tunnel
                    remote_del_tunnel
                    local_add_tunnel
                    remote_add_tunnel
                    sleep 5s
                done
            done
        done
        ;;
        --stop)
        for CONFIG in $(ls ${STATICIPSECDIR}/conf.d/*.conf)
        do
            read_conf ${CONFIG}
            local_del_tunnel
            remote_del_tunnel
        done
        ;;
        --restart)
        for CONFIG in $(ls ${STATICIPSECDIR}/conf.d/*.conf)
        do
            read_conf ${CONFIG}
            local_del_tunnel
            remote_del_tunnel
            local_add_tunnel
            remote_add_tunnel
        done
        ;;
        --dpd)
        while true
        do
            for CONFIG in $(ls ${STATICIPSECDIR}/conf.d/*.conf)
            do
                read_conf ${CONFIG}
                probe_session
                sleep 1s
            done
        done
        ;;
        *)
        usage
        ;;
esac
}

main $*
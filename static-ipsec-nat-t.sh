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
    declare -g ori_local_public_ip=$(awk -F ' *= *' '$1=="ori_local_public_ip"{print $2}' "${CONFIG}")
    declare -g nat_local_public_ip=$(awk -F ' *= *' '$1=="nat_local_public_ip"{print $2}' "${CONFIG}")
    declare -g nat_local_public_ip_online_get=$(awk -F ' *= *' '$1=="nat_local_public_ip_online_get"{print $2}' "${CONFIG}")
    declare -g local_private_ip=$(awk -F ' *= *' '$1=="local_private_ip"{print $2}' "${CONFIG}")
    declare -g spi_id=$(awk -F ' *= *' '$1=="spi_id"{print $2}' "${CONFIG}")
    declare -g auth_sha256=$(awk -F ' *= *' '$1=="auth_sha256"{print $2}' "${CONFIG}")
    declare -g enc_aes=$(awk -F ' *= *' '$1=="enc_aes"{print $2}' "${CONFIG}")
    declare -g remote_public_ip=$(awk -F ' *= *' '$1=="remote_public_ip"{print $2}' "${CONFIG}")
    declare -g remote_private_ip=$(awk -F ' *= *' '$1=="remote_private_ip"{print $2}' "${CONFIG}")
    declare -g ori_local_port=$(awk -F ' *= *' '$1=="ori_local_port"{print $2}' "${CONFIG}")
    declare -g nat_local_port=$(awk -F ' *= *' '$1=="nat_local_port"{print $2}' "${CONFIG}")
    declare -g remote_port=$(awk -F ' *= *' '$1=="remote_port"{print $2}' "${CONFIG}")
    declare -g local_default_if=$(awk -F ' *= *' '$1=="local_default_if"{print $2}' "${CONFIG}")
    declare -g remote_default_if=$(awk -F ' *= *' '$1=="remote_default_if"{print $2}' "${CONFIG}")
    declare -g remote_ssh_user=$(awk -F ' *= *' '$1=="remote_ssh_user"{print $2}' "${CONFIG}")
    declare -g remote_ssh_port=$(awk -F ' *= *' '$1=="remote_ssh_port"{print $2}' "${CONFIG}")
    declare -g espmode=$(awk -F ' *= *' '$1=="espmode"{print $2}' "${CONFIG}")
}

#仅终端打印日志
save_log(){
    ctime=$(date "+%Y-%m-%d %H:%M:%S")
    echo "${ctime} [$1][${CONFIG_FILE_NAME}]:$2"
}

local_del_tunnel(){
    sudo /sbin/ip xfrm state del src ${ori_local_public_ip} dst ${remote_public_ip} proto esp spi ${spi_id} \
    > /dev/null 2>&1 || save_log "INFO" "delete local state failed !!!"
    sudo /sbin/ip xfrm state del src ${remote_public_ip} dst ${ori_local_public_ip} proto esp spi ${spi_id} \
    > /dev/null 2>&1 || save_log "INFO"  "delete local state failed !!!"
    sudo /sbin/ip xfrm policy del src ${remote_private_ip} dst ${local_private_ip} dir in ptype main \
    > /dev/null 2>&1 || save_log "INFO"  "delete local policy failed !!!"
    sudo /sbin/ip xfrm policy del src ${local_private_ip} dst ${remote_private_ip} dir out ptype main \
    > /dev/null 2>&1 || save_log "INFO"  "delete local policy failed !!!"
}

local_add_tunnel(){
    espmode=$(cat ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_espmode)
    # save_log "DEBUG" "encap ${espmode}"
    save_log "INFO" "$(sudo /sbin/ip xfrm state add src ${ori_local_public_ip} dst ${remote_public_ip} proto esp spi ${spi_id} reqid ${spi_id} \
    mode tunnel auth sha256 ${auth_sha256} enc aes ${enc_aes} encap ${espmode} ${ori_local_port} ${remote_port} 0.0.0.0)" \
    || save_log "INFO"  "add state failed !!!"
        
    save_log "INFO" "$(sudo /sbin/ip xfrm state add src ${remote_public_ip} dst ${ori_local_public_ip} proto esp spi ${spi_id} reqid ${spi_id} \
    mode tunnel auth sha256 ${auth_sha256} enc aes ${enc_aes} encap ${espmode} ${remote_port} ${ori_local_port} 0.0.0.0)" \
    || save_log "INFO"  "add state failed !!!"
    
    save_log "INFO" "$(sudo /sbin/ip xfrm policy add src ${remote_private_ip} dst ${local_private_ip} dir in ptype main \
    tmpl src ${remote_public_ip} dst ${ori_local_public_ip} proto esp reqid ${spi_id} mode tunnel)" \
    || save_log "INFO"  "add policy failed !!!"
    
    save_log "INFO" "$(sudo /sbin/ip xfrm policy add src ${local_private_ip} dst ${remote_private_ip} dir out ptype main \
    tmpl src ${ori_local_public_ip} dst ${remote_public_ip} proto esp reqid ${spi_id} mode tunnel)" \
    || save_log "INFO"  "add policy failed !!!"
}

remote_del_tunnel(){
    temp_nat_local_public_ip=$(cat ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_nat_local_public_ip)
    [ -z ${temp_nat_local_public_ip} ] \
    || nat_local_public_ip=$(cat ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_nat_local_public_ip)
    if [ ! -z ${nat_local_public_ip} ];then
        ssh ${remote_ssh_user}@${remote_public_ip} -p ${remote_ssh_port} /bin/bash << EOF
        sudo /sbin/ip xfrm state del src ${nat_local_public_ip} dst ${remote_public_ip} proto esp spi ${spi_id} \
        > /dev/null 2>&1 || echo "delete remote state failed !!!"
        sudo /sbin/ip xfrm state del src ${remote_public_ip} dst ${nat_local_public_ip} proto esp spi ${spi_id} \
        > /dev/null 2>&1 || echo "delete remote state failed !!!"
        sudo /sbin/ip xfrm policy del src ${remote_private_ip} dst ${local_private_ip} dir out ptype main \
        > /dev/null 2>&1 || echo "delete remote policy failed !!!"
        sudo /sbin/ip xfrm policy del src ${local_private_ip} dst ${remote_private_ip} dir in ptype main \
        > /dev/null 2>&1 || echo "delete remote policy failed !!!"
EOF
    else
        save_log "INFO"  "<nat_local_public_ip> not FOUND, remote_del_tunnel EXIT"
    fi
}

remote_add_tunnel_via_ssh(){
    espmode=$(cat ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_espmode)
    save_log "INFO" "$(ssh ${remote_ssh_user}@${remote_public_ip} -p ${remote_ssh_port} /bin/bash << EOF
    # sudo /sbin/ip xfrm state del src ${nat_local_public_ip} dst ${remote_public_ip} proto esp spi ${spi_id}
    # sudo /sbin/ip xfrm state del src ${remote_public_ip} dst ${nat_local_public_ip} proto esp spi ${spi_id}
    # sudo /sbin/ip xfrm policy del src ${remote_private_ip} dst ${local_private_ip} dir in ptype main
    # sudo /sbin/ip xfrm policy del src ${local_private_ip} dst ${remote_private_ip} dir out ptype main

    sudo /sbin/ip xfrm state add src ${nat_local_public_ip} dst ${remote_public_ip} proto esp spi ${spi_id} reqid ${spi_id} \
    mode tunnel auth sha256 ${auth_sha256} enc aes ${enc_aes} encap ${espmode} ${nat_local_port} ${remote_port} 0.0.0.0 \
    > /dev/null 2>&1|| echo "add remote state failed !!!"
    
    sudo /sbin/ip xfrm state add src ${remote_public_ip} dst ${nat_local_public_ip} proto esp spi ${spi_id} reqid ${spi_id} \
    mode tunnel auth sha256 ${auth_sha256} enc aes ${enc_aes} encap ${espmode} ${remote_port} ${nat_local_port} 0.0.0.0 \
    > /dev/null 2>&1|| echo "add remote state failed !!!"
    
    sudo /sbin/ip xfrm policy add src ${remote_private_ip} dst ${local_private_ip} dir out ptype main \
    tmpl src ${remote_public_ip} dst ${nat_local_public_ip} proto esp reqid ${spi_id} mode tunnel \
    > /dev/null 2>&1|| echo "add remote policy failed !!!"

    sudo /sbin/ip xfrm policy add src ${local_private_ip} dst ${remote_private_ip} dir in ptype main \
    tmpl src ${nat_local_public_ip} dst ${remote_public_ip} proto esp reqid ${spi_id} mode tunnel \
    > /dev/null 2>&1 || echo "add remote policy failed !!!"
EOF
)"
}

update_nat_argument(){
    # 为空，在线获取，非空，不获取，涉及变量的更新，不能用[]进行判断
    save_log "INFO" "updating nat_local_public_ip"
    if [ ! -z ${nat_local_public_ip_online_get} ];then
        save_log "INFO" "nat_local_public_ip_online_get FOUND !!"
        declare -g nat_local_public_ip=$(curl -s http://myip.ipip.net | grep  -oE "([0-9]{1,3}\.){1,3}[0-9]{1,3}")
        save_log "INFO" "get online nat_local_public_ip=${nat_local_public_ip}"
    fi
    conntrack_result=$(ssh ${remote_ssh_user}@${remote_public_ip} -p ${remote_ssh_port} /bin/bash << EOF
    sudo /usr/sbin/conntrack -L -p udp | grep "src=${nat_local_public_ip}" | grep "dport=${remote_port}"
EOF
    )

#     conntrack_result=$(ssh ${remote_ssh_user}@${remote_public_ip} -p ${remote_ssh_port} /bin/bash << EOF
#     sudo /usr/sbin/conntrack -E --proto udp --orig-port-dst 1100 | grep "src=${nat_local_public_ip}" | grep "dport=${remote_port}"
# EOF
#     )

    save_log "INFO" "${conntrack_result}"

    save_log "INFO" "nat_local_public_ip=${nat_local_public_ip}"
    echo "${nat_local_public_ip}" > ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_nat_local_public_ip

    # nat_local_port=$(echo ${conntrack_result} \
    # | awk '{print $4,$6}' \
    # | grep -E "src=${nat_local_public_ip} dst=${remote_public_ip} sport=[0-9]{1,5} dport=${remote_port}" \
    # | grep -oE "sport=[0-9]{1,5}" | grep -v "sport=${remote_port}" | sed "s/sport=//" | tail -1)

    nat_local_port=$(echo ${conntrack_result} \
    | grep -oE "(sport=[0-9]{1,5})" \
    | grep -v "${remote_port}" \
    | grep -oE "[0-9]{1,6}" \
    | xargs )

    # 保存espmode的值到cache
    [ -z ${espmode} ] \
    && espmode="espinudp-nonike"
    save_log "INFO" "espmode=${espmode}"
    echo "${espmode}" > ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_espmode

    # 保存nat_local_port的值到cache
    save_log "INFO" "nat_local_port=${nat_local_port}"
    echo "${nat_local_port}" > ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_nat_local_port
}

probe_session(){
    save_log "INFO" "$(ping -I ${local_private_ip} ${remote_private_ip} -c 1 -i 0.2 -W 1)"
}

dpd_keepalive(){
    # [ ! -z ${keepalive} ] && temp_keepalive=${keepalive} || temp_keepalive=0
    [ ! -f ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_keepalive ] \
    && echo "0" > ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_keepalive

    temp_keepalive=$(cat ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_keepalive)
    
    echo ${temp_keepalive} | grep -E "^[0-9]$" > /dev/null 2>&1
    [ $? -ne 0 ] \
    && echo "0" > ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_keepalive

    temp_keepalive=$(cat ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_keepalive)

    ping -I ${local_private_ip} ${remote_private_ip} -c 1 -i 0.2 -W 1 > /dev/null 2>&1 \
    && (save_log "INFO" "${CONFIG_FILE_NAME} peer alive";\
    echo "0" > ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_keepalive;\
    return 0) \
    || (save_log "INFO" "${CONFIG_FILE_NAME} peer dead,time ${temp_keepalive}";\
    echo "${temp_keepalive}+1" | bc > ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_keepalive;\
    return 1)

    last_keepalive=$(cat ${STATICIPSECDIR}/cache/${CONFIG_FILE_NAME}_keepalive)
}

remote_add_tunnel(){
    probe_session
    update_nat_argument
    remote_add_tunnel_via_ssh
}

clear_cache(){
    rm -rf ${STATICIPSECDIR}/cache/*
    save_log "INFO" "cache has been clear"
}


main(){
    case $1 in
        --start)
        clear_cache
        while true
        do
            for CONFIG in $(ls ${STATICIPSECDIR}/conf.d/*.conf)
            do
                read_conf ${CONFIG}
                dpd_keepalive
                while [ ${last_keepalive} -ge 3 ]
                do
                    save_log "INFO" "clear ${CONFIG_FILE_NAME} tunnel session and re-negotiate"
                    local_del_tunnel
                    remote_del_tunnel
                    local_add_tunnel
                    remote_add_tunnel
                    break
                done
                sleep 5s
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
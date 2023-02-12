#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <netinet/in_systm.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/udp.h>
#include <net/if.h>

#define _LINUX_IN6_H
#include <linux/xfrm.h>

int set_ipsec_policy(int fd)
{
    struct xfrm_userpolicy_info policy;
    u_int sol, ipsec_policy;

    sol = IPPROTO_IP;
    ipsec_policy = IP_XFRM_POLICY;


    memset(&policy, 0, sizeof(policy));
    policy.action = XFRM_POLICY_ALLOW;
    policy.sel.family = AF_INET;

    policy.dir = XFRM_POLICY_OUT;

    if (setsockopt(fd, sol, ipsec_policy, &policy, sizeof(policy)) < 0)
    {
        printf("unable to set IPSEC_POLICY on socket: %s\n",strerror(errno));
        return -1;
    }
    policy.dir = XFRM_POLICY_IN;
    if (setsockopt(fd, sol, ipsec_policy, &policy, sizeof(policy)) < 0)
    {
        printf("unable to set IPSEC_POLICY on socket: %s\n",strerror(errno));
        return -1;
    }
    return 0;
}


int main(int argc, char *argv[])
{
    int sockfd = -1;

    struct sockaddr_in host_addr;
    if((sockfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP))<0)
    {
        printf("socket() error!\n");
        exit(1);
    }
    memset(&host_addr, 0, sizeof(host_addr));
    host_addr.sin_family = AF_INET;
    host_addr.sin_port = htons(atoi(argv[1]));
    host_addr.sin_addr.s_addr = htonl(INADDR_ANY);

    const int on = 1;
    if(setsockopt(sockfd, IPPROTO_IP, SO_REUSEADDR, &on, sizeof(on))<0)
    {
        printf("setsockopt() error!\n");
        exit(0);
    }
    int encap = 1;

    if(setsockopt(sockfd, IPPROTO_UDP, 100, &encap, sizeof(encap))<0)
    {
        printf("setsockopt() udp error!\n");
        exit(0);
    }

    if (bind(sockfd, (struct sockaddr*)&host_addr, sizeof(host_addr)) < 0)
    {
        printf("unable to bind socket: %s\n", strerror(errno));
        close(sockfd);
        return -1;
    }

    set_ipsec_policy(sockfd);
    printf("bind ..\n");


    while(1) {
        sleep(1);
    }
    return 0;

}
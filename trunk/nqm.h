#ifndef NQM_H_
#define NQM_H_

#define __USE_BSD
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#define __FAVOR_BSD
#include <netinet/tcp.h>
#include <netinet/udp.h>
#include <arpa/inet.h>

// Prototypes
int identify_ip_protocol (char *payload);
char *get_src_ip_str(char *payload);
char *get_dst_ip_str(char *payload);
int get_tcp_src_port (char *payload);
int get_tcp_dst_port (char *payload);
int get_udp_src_port(char *payload);
int get_udp_dst_port (char *payload);

#endif /*NQM_H_*/

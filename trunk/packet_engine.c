/**************************************************************************************************
 *  packet_engine.c
 *
 *  Description:  Framework for capturing packets from NFQUEUE for processing. 
 *
 *	Before you run this you need to direct packets to the NFQUEUE queue, for example :
 *		  # iptables -A INPUT -p tcp -j NFQUEUE --queue-num 10
 *		  # iptables -A INPUT -p udp -j NFQUEUE --queue-num 10
 *
 *		  These will direct all tcp or udp packets respectively.  Other iptable filters
 *		  can be crafted to redirect specfic packets to the queue.  If you dont redirect any
 *		  packets to the queue your program won't see any packets.
 *
 *  to remove the filter: # iptables --flush
 *
 *  Must execute as root: # ./packet_engine -q num
 **************************************************************************************************/

#include "nqm.h"
#include <linux/netfilter_ipv4.h>
#include <libnetfilter_queue/libnetfilter_queue.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>	// for multi-threads
#include <netdb.h>		// for getservbyname()

// constants
// ---------
#define PE_VERSION	"1.0"
#define BUFSIZE		4096
#define PAYLOADSIZE	21
#define IN 1
#define OUT 0

// global variables
// ---------
char *logfilename = "/var/log/monitorS.log";	// program's log file
char *cfg_serv_filename = "/usr/local/etc/services.conf";		// program's config file for services
char *cfg_network_filename = "/usr/local/etc/networks.conf";	// program's config file for networks
double machine[255][255];
int max_x=0, max_y=0;

int num_serv = 0, num_networks = 0;
struct io_services {
	char name[20];				// name of service
	double v_pkt_in;			// volume of packet in
	double v_pkt_out;			// volume of packet out
	unsigned int *port;			// list of ports
	unsigned int n_port;
} services[10];
struct io_networks {
	char name[20];
	double v_pkt_in;
	double v_pkt_out;
	unsigned int *list_ip;		// min + max of list IP
	unsigned int n_list;
} networks[6];

// prototypes
// ----------
short int netlink_loop(unsigned short int queuenum);
static int nfqueue_cb(struct nfq_q_handle *qh, struct nfgenmsg *nfmsg, struct nfq_data *nfa, void *data);
void count_services(int s_port, int p_code, int in, int size);
void count_networks(char *str, int in, int size);
void print_options(void);
void on_quit(void);
void writelog(char *);
void read_log(char *);
void read_config();
void print_values();
int get_port_of_serv(char *, char *);
void get_limit_ip(char *str, unsigned int *list_ip, unsigned int n_list);

// functions for thread 
// --------------------
// 1.
void *tcap_packet_function(void *threadarg) {
	printf("Thread: sniffing packet...started\n");
	netlink_loop(*(unsigned short int *)threadarg);
	pthread_exit(NULL);
}

// 2.
void *twrite_log_function() {
	printf("Thread: write log file...started\n");
	while (1) {
		sleep(100);
		writelog(logfilename);
	}
	pthread_exit(NULL);
}

// main function
// -------------
int main(int argc, char **argv) {
	int ret = 0;
	unsigned short int queuenum = 0;	// queue number to read
	int daemonized = 0;					// for background program

	// check parameters
	// ----------------
	if (argc < 1) {
		print_options();
		exit(-1);
	}
	
	// check root user ?
	// -----------------
	if (getuid() != 0) {
		fprintf(stderr, "\nPacket_engine Version %s\n", PE_VERSION);
		fprintf(stderr, "Copyright (c) NGO Quang Minh\n\n");
		fprintf(stderr, "This program can be run only by the system administrator\n\n");
		exit(-1);
	}
	
	// register a function to be called at normal program termination
	// --------------------------------------------------------------
	ret = atexit(on_quit);
	if ( ret ) {
		fprintf(stderr,"Cannot register exit function, terminating.\n");
		exit(-1);
	}
	
	// parse command line
	// ------------------
	int done = 0;
	while (!done) {		//scan command line options
		ret = getopt(argc, argv, ":hq:l:B:");		
		switch (ret) {		
			case -1 :
				done = 1;
				break;
			case 'h':
				print_options();
				exit(-1);
			case 'q':
				queuenum = (unsigned short int)atoi(optarg);				
				break;			
			case 'l':
				logfilename = optarg;
				break;
			case 'B':
				daemonized = 1;
				break;
			case '?':	// unknown option
				fprintf(stderr,
							"\nInvalid option or missing parameter, use packet_engine -h for help\n\n");
				exit(-1);
		}
	}	
	
	// initialization
	// --------------
	read_config();
	printf("Initialization...OK\n");
	
	// continue to read log file if necessair
	// --------------------------------------
	FILE *f = fopen(logfilename, "r");
	if (f != NULL) {
		printf("Logfile existed in %s! \n", logfilename);
		printf("Do you want to continue with this log file ? (y/n): \n"); 
		char c = ' ';
		while (c != 'y' && c != 'n') {
			c = tolower(fgetc(stdin));
		}
		
		if (c == 'y')
			read_log(logfilename);
		fclose(f);
	}
	
	// printf for test
	// ---------------
	//print_values(stdin);
	
	// check if program run in background ?
	// ------------------------------------
	if (daemonized) {
		switch (fork()) {
			case 0:			/* child */
				setsid();
				freopen("/dev/null", "w", stdout);	/* redirect std output */
				freopen("/dev/null", "r", stdin);	/* redirect std input */
				freopen("/dev/null", "w", stderr);	/* redirect std error */
				break;
			case -1:		/* error */
				fprintf(stderr,	"\nFork error, the program cannot run in background\n\n");
				exit(1);
			default:		/* parent */
				exit(0);
		}
    }

	// begin with netfilter & write log file
	// -------------------------------------
	pthread_t tcap_packet, twrite_log;
	ret = pthread_create(&tcap_packet, NULL, tcap_packet_function,
					(void *) &queuenum);
	if (ret) {
		printf("ERROR; return code from pthread_create() is %d\n", ret);
		exit(-1);
	}
	
	ret = pthread_create(&twrite_log, NULL, twrite_log_function, NULL);
	if (ret) {
		printf("ERROR; return code from pthread_create() is %d\n", ret);
		exit(-1);
	}
		
	pthread_exit(NULL);
}

// loop to process a received packet at the queue
// ----------------------------------------------
short int netlink_loop(unsigned short int queuenum) {
	struct nfq_handle *h;
	struct nfq_q_handle *qh;
	struct nfnl_handle *nh;
	int fd, rv;
	char buf[BUFSIZE];

	// opening library handle
	h = nfq_open();
	if (!h) {
		printf("Error during nfq_open()\n");
		exit(-1);
	}

	// unbinding existing nf_queue handler for AF_INET (if any)
	// an error with Kernel 2.6.23 or above --> commented 2 lines 
	if (nfq_unbind_pf(h, AF_INET) < 0) {
		//printf("Error during nfq_unbind_pf()\n");
		//exit(-1);
	}
	
	// binds the given queue connection handle to process packets.
	if (nfq_bind_pf(h, AF_INET) < 0) {
		printf("Error during nfq_bind_pf()\n");
		exit(-1);
	}
	printf("NFQUEUE: binding to queue '%hd'\n", queuenum);
	
	// create queue
	qh = nfq_create_queue(h,  queuenum, &nfqueue_cb, NULL);
	if (!qh) {
		printf("Error during nfq_create_queue()\n");
		exit(-1);
	}
	
	// sets the amount of data to be copied to userspace for each packet queued
	// to the given queue.
	if (nfq_set_mode(qh, NFQNL_COPY_PACKET, 0xffff) < 0) {
		printf("Can't set packet_copy mode\n");
		exit(-1);
	}

	// returns the netlink handle associated with the given queue connection handle.
	// Possibly useful if you wish to perform other netlink communication
	// directly after opening a queue without opening a new netlink connection to do so
	nh = nfq_nfnlh(h);

	// returns a file descriptor for the netlink connection associated with the
	// given queue connection handle.  The file descriptor can then be used for
	// receiving the queued packets for processing.
	fd = nfnl_fd(nh);
	while ((rv = recv(fd, buf, sizeof(buf), 0)) && rv >= 0) {
		printf("\n------------\n");
		// triggers an associated callback for the given packet received from the queue.  
		// Packets can be read from the queue using nfq_fd() and recv().  
		nfq_handle_packet(h, buf, rv);
	}

	// unbinding before exit
	printf("NFQUEUE: unbinding from queue '%hd'\n", queuenum);
	nfq_destroy_queue(qh);
	nfq_close(h);
	return(0);
}

// function callback for packet processing
// ---------------------------------------
static int nfqueue_cb(
		struct nfq_q_handle *qh, 
		struct nfgenmsg *nfmsg,
		struct nfq_data *nfa, 
		void *data) {
	
	struct nfqnl_msg_packet_hdr *ph;	
	ph = nfq_get_msg_packet_hdr(nfa);
	
	if (ph) {
		int id = 0, size = 0;
		char *full_packet; // get data of packet (payload)
		
		id = ntohl(ph->packet_id);		
		printf("hw_protocol = 0x%04x hook = %u id = %u \n", 
				ntohs(ph->hw_protocol), ph->hook, id);		
		
		size = nfq_get_payload(nfa, &full_packet);
		
		int id_protocol = identify_ip_protocol(full_packet);		
		printf("Packet from %s", get_src_ip_str(full_packet));
		printf(" to %s\n", get_dst_ip_str(full_packet));
								
		// percent of protocol
		// -------------------
		switch (ph->hook) {
			case NF_IP_LOCAL_IN :	// packets IN
				count_networks(get_dst_ip_str(full_packet), IN, size);
				switch (id_protocol) {
					case IPPROTO_ICMP :
						//num_pkt_protocol[0].in++;
						break;
					case IPPROTO_TCP : 
						//num_pkt_protocol[1].in++;
						printf("IN SRC Port: %d\n", get_tcp_src_port(full_packet));
						printf("IN DST Port: %d\n", get_tcp_dst_port(full_packet));
						count_services(get_tcp_src_port(full_packet), IPPROTO_TCP, IN, size);
						break;
					case IPPROTO_UDP :
						//num_pkt_protocol[2].in++;
						printf("IN SRC Port: %d\n", get_udp_src_port(full_packet));
						printf("IN DST Port: %d\n", get_tcp_dst_port(full_packet));
						count_services(get_udp_src_port(full_packet), IPPROTO_UDP, IN, size);
						break;
					case IPPROTO_ESP :
						//num_pkt_protocol[3].in++;
						break;
					default :
						//num_pkt_protocol[4].in++;
						break;
				}
				break;
			case NF_IP_LOCAL_OUT : // packets OUT
				count_networks(get_src_ip_str(full_packet), OUT, size);
				switch (id_protocol) {
					case IPPROTO_ICMP :
						//num_pkt_protocol[0].out++;
						break;
					case IPPROTO_TCP : 
						//num_pkt_protocol[1].out++;
						printf("OUT SRC Port: %d\n", get_tcp_src_port(full_packet));
						printf("OUT DST Port: %d\n", get_tcp_dst_port(full_packet));
						count_services(get_tcp_dst_port(full_packet), IPPROTO_TCP, OUT, size);
						break;
					case IPPROTO_UDP :
						//num_pkt_protocol[2].out++;
						printf("OUT SRC Port: %d\n", get_udp_src_port(full_packet));
						printf("OUT DST Port: %d\n", get_tcp_dst_port(full_packet));
						count_services(get_udp_dst_port(full_packet), IPPROTO_UDP, OUT, size);
						break;
					case IPPROTO_ESP :
						//num_pkt_protocol[3].out++;
						break;
					default :
						//num_pkt_protocol[4].out++;
						break;
				}
				break;
			default :	// Ignore the rest (like: FORWARD, )
				break;				
		}
		
		// let the packet continue on.  NF_ACCEPT will pass the packet
		// -----------------------------------------------------------
		nfq_set_verdict(qh, id, NF_ACCEPT, 0, NULL);
	} else {
		printf("NFQUEUE: can't get msg packet header.\n");
		return(1);		// from nfqueue source: 0 = ok, >0 = soft error, <0 hard error
	}

	return(0);
}

int find_port(int *l_port, int n_port, int port) {
	int i=0;

	for (i=0; i<n_port; i++) {
		if (l_port[i] == port) return 1;
	}
	return 0;
}

/*
 * Count the services TCP/UDP's packets
 */
void count_services(int s_port, int p_code, int in, int size) {
	int i = 0;

	for (i = 0; i < num_serv; i++) {
		if (find_port(services[i].port, services[i].n_port, s_port)) {
			if (in)
				services[i].v_pkt_in += size;
			else
				services[i].v_pkt_out += size;
			break;
		}
	}
}

int find_ip(int *list_ip, int n_list, int a) {	
	int i=0;
	for (i=0; i<n_list; i++) {
		if (a >= list_ip[i*2] && a <= list_ip[i*2+1]) return 1;
	}
	return 0;
}

/*
 * Count the network's packets
 */
void count_networks(char *str, int in, int size) {
	int i = 0;
	char *ptr1 = strchr(str, '.');
	ptr1 = strchr(ptr1 + 1, '.');
	int a = atoi(ptr1 + 1);
	ptr1 = strrchr(str, '.');
	int b = atoi(ptr1 + 1);	

	machine[a][b] += size;
	if (machine[max_x][max_y] < machine[a][b]) {
		max_x = a;
		max_y = b;
	}

	a = (a << 8) + b;	
	for (i = 0; i < num_networks; i++) {
		if (find_ip(networks[i].list_ip, networks[i].n_list, a)) {
			if (in)
				networks[i].v_pkt_in += size;
			else
				networks[i].v_pkt_out += size;
			break;
		}
	}
}

/*
 * this function displays usages of the program
 */
void print_options(void) {
	printf("\nPacket_engine %s created by NQ.Minh",PE_VERSION);
	printf("\n\nSyntax: packet_engine [ -h ] [ -q queue-num] [ -l logfile ] [ -B ]\n\n");
	printf("  -h\t\t- display this help and exit\n");
	printf("  -q <0-65535>\t- listen to the NFQUEUE (as specified in --queue-num with iptables)\n");
	printf("  -l <logfile>\t- allow to specify an alternate log file\n");
	printf("  -B\t\t- run this program in background.\n\n");
}

/*
 * this function is executed at the end of program
 */
void on_quit(void) {
	if (services != NULL)
		;//free(services);
	printf("Program termined!\n");
}

/*
 * this function writes data to log file
 */
void writelog(char *filename) {
	FILE *fd = fopen(filename, "w+");
	if (fd == NULL) {
		printf("Unable to open log file\n");
		exit(-1);
	}
	
	print_values(fd);

	fflush(stdout);
	fclose(fd);
}

/*
 * this function reads data from the log file into globals variables 
 */
void read_log(char *filename) {
	FILE *fd = fopen(filename, "r");
	if (fd == NULL) {
		printf("Unable to open log file\n");
		exit(-1);
	}
	
	char temp[10];
	double test1 = 0, test2 = 0;
	int i = 0;
	while (! feof(fd)) {
		if (i < num_serv + num_networks) {
			fscanf(fd, "%s", temp);
			fscanf(fd, "%lf", &test1);
			fscanf(fd, "%lf", &test2);
			
			if (i < num_serv) {
				//printf("out-if:%s %s\n", temp, services[i].name);
				if (!strcmp(temp, services[i].name)) {
					//printf("%s %.0f %.0f\n", temp, test1, test2);
					services[i].v_pkt_in = test1;
					services[i].v_pkt_out = test2;
					i++;
				}
			} else {
				if (!strcmp(temp, networks[i-num_serv].name)) {
					//printf("%s %.0f %.0f\n", temp, test1, test2);
					networks[i-num_serv].v_pkt_in = test1;
					networks[i-num_serv].v_pkt_out = test2;
					i++;
				}
			}
		} else {
			fscanf(fd, "%d", &max_x);
			fscanf(fd, "%d", &max_y);
			fscanf(fd, "%lf", &machine[max_x][max_y]);
		}
	}
	if (i < num_serv + num_networks) {
		printf("Warning: config file is changed before reading log file !\n");
		printf("Continue ? (y/n) : ");
		char c = ' ';
		while (c != 'y' && c != 'n') {
			c = tolower(fgetc(stdin));
		}
				
		if (c == 'n')
			exit(-1);
	} else
		printf("Reading log file...OK\n");
	
	fclose(fd);
}

void trim(char *s) {
	char ret[80];
	int i=0, j=0;
	while (i < strlen(s) && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n')) {
		i++;
	}
	while (i < strlen(s) && (s[i] != ' ' || s[i] != '\t' || s[i] != '\n')) {
		ret[j++] = s[i++];
	}
	ret[j] = '\0';
	strcpy(s, ret);
}

/*
 * Function to read the configuration from config file into the global variables
 */
void read_config() {
	printf("Reading config file...\n");
	
	// services config file
	// --------------------
	FILE *fd = fopen(cfg_serv_filename, "r");
	if (fd == NULL) {
		printf("ERROR: Unable to open config file\n");
		exit(-1);
	}
	
	char str[80];	
	while (fgets(str, 80, fd) != NULL) {
		if (str[strlen(str)-1] == '\n')
			str[strlen(str)-1] = '\0';
		if (str[0] != '#') {
			char *token;
			if (strchr(str, '!') != NULL) {
				token = strtok(str, " ,;:!");
				trim(token);
				num_serv++;
				//services = (struct io_services *) realloc(services, sizeof(struct io_services) * num_serv);
				sprintf(services[num_serv-1].name, "%s", token);
				services[num_serv-1].v_pkt_in = services[num_serv-1].v_pkt_out = 0;
				services[num_serv-1].n_port = 0;
				continue;
			}
			
			trim(str);
			token = strtok(str, " ,;:!");
						
			while (token != NULL) {
				trim(token);
				services[num_serv-1].n_port++;
				services[num_serv-1].port = (unsigned int *) realloc(services[num_serv-1].port, 
						sizeof(unsigned int) * services[num_serv-1].n_port);
				services[num_serv-1].port[services[num_serv-1].n_port-1]=get_port_of_serv(token, "tcp");
				token = strtok(NULL, " ,;:!");
			}
		}
	}
	int i;		
	for (i=0; i<num_serv; i++) {
		printf("%d: %s {", i+1, services[i].name);
		int j;
		for (j=0; j<services[i].n_port; j++){
			printf(" %d ", services[i].port[j]);		
		}
		printf("}\n");
	}
	
	fclose(fd);
	
	// networks config file
	// --------------------
	fd = fopen(cfg_network_filename, "r");
	if (fd == NULL) {
		printf("ERROR: Unable to open config file\n");
		exit(-1);
	}	
		
	while (fgets(str, 80, fd) != NULL) {
		if (str[strlen(str)-1] == '\n')
			str[strlen(str)-1] = '\0';
		if (str[0] != '#') {
			char *token;
			if (strchr(str, '!') != NULL) {
				token = strtok(str, " ,;:!");
				trim(token);
				num_networks++;
				sprintf(networks[num_networks-1].name, "%s", token);
				networks[num_networks-1].v_pkt_in = networks[num_networks-1].v_pkt_out = networks[num_networks-1].n_list = 0;
				continue;
			}
			
			trim(str);
			token = strtok(str, " ,;:!");
						
			while (token != NULL) {
				trim(token);
				networks[num_networks-1].n_list++;
				//printf("%s n_list: %d\n", token, networks[num_networks-1].n_list);
				networks[num_networks-1].list_ip = (unsigned int *) realloc(networks[num_networks-1].list_ip, 
						sizeof(unsigned int) * networks[num_networks-1].n_list * 2);
				get_limit_ip(token, networks[num_networks-1].list_ip, networks[num_networks-1].n_list);
				token = strtok(NULL, " ,;:!");
			}
		}
	}
		
	for (i=0; i<num_networks; i++) {
		printf("%d: %s {\n", i+1, networks[i].name);
		int j;
		for (j=0; j<networks[i].n_list; j++){
			printf("\t%d -> %d\n", networks[i].list_ip[2*j], networks[i].list_ip[2*j+1]);		
		}
		printf("}\n");
	}
	
	fclose(fd);
}

void print_values(FILE *fd) {
	//fprintf(fd, "Statistic: \n");
	int i = 0;
	//printf("\tServices\n");
	for (i=0; i<num_serv; i++) {
		fprintf(fd, "%s %.0lf %.0lf\n", 
				services[i].name, services[i].v_pkt_in, services[i].v_pkt_out);
	}
	//printf("\tNetworks\n");
	for (i=0; i<num_networks; i++) {
		fprintf(fd, "%s %.0lf %.0lf\n", 
				networks[i].name, networks[i].v_pkt_in, networks[i].v_pkt_out);
	}

	fprintf(fd, "%d %d %.0lf\n", max_x, max_y, machine[max_x][max_y]);
}

/*
 * To get port number of service
 * Input: name of service, protocol
 * Output: port number (=0 if not found)
 */
int get_port_of_serv(char *name, char *proto) {
	struct servent *sp= NULL;
	
	//printf("Trying to get details for service %s running over %s...",	name, proto);

	sp = getservbyname(name, proto);

	if (sp) {
		//printf("OK\n");
		return ntohs(sp->s_port);		
	} else {
		//printf("failed\n");
		return 0;
	}
}

/*
 * 
 */
void get_limit_ip(char *str, unsigned int *list_ip, unsigned int n_list) {
	char *ptr1 = strchr(str, '.');
	ptr1 = strchr(ptr1 + 1, '.');
	int a = atoi(ptr1 + 1);
	ptr1 = strrchr(str, '.');
	int b = atoi(ptr1 + 1);
	ptr1 = strrchr(str, '/');
	int c = b;
	if (ptr1 != NULL) {
		c = 32 - atoi(ptr1+1);
		c = (1 << c) - 1 + b;
	}
	//printf("%d %d %d \n", a, b, c);
	list_ip[2*(n_list-1)] = a * 256 + b;
	list_ip[2*n_list -1] = a * 256 + c;
}

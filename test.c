#include <arpa/inet.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>
#include <pcap/pcap.h>

#define TRUE 1
#define FALSE 0

int sendBind = 0;
int ldapPort = 0;
char* ip;



void print_usage(char ***argv) {
    printf("Usage: %s, [-m] [-f] [-b] [-p] [-a]", *argv[0]);
    //exit(1);
}

int sendMessage(uint8_t *message, size_t length) {
    char bindMessage[49] = {0x30, 0x2f, 0x02, 0x01, 0x01, 0x60, 0x2a, 0x02, 0x01,
                            0x03, 0x04, 0x14, 0x63, 0x6e, 0x3d, 0x64, 0x69, 0x72,
                            0x65, 0x63, 0x74, 0x6f, 0x72, 0x79, 0x20, 0x6d, 0x61,
                            0x6e, 0x61, 0x67, 0x65, 0x72, 0x80, 0x0f, 0x73, 0x65,
                            0x63, 0x52, 0x65, 0x74, 0x5f, 0x70, 0x61, 0x73, 0x73,
                            0x57, 0x6f, 0x72, 0x64};
    char bindResponse[14] = {0x30, 0x0c, 0x02, 0x01, 0x01, 0x61, 0x07,
                             0x0a, 0x01, 0x00, 0x04, 0x00, 0x04, 0x00};
    struct sockaddr_in6 server_addr;
    int sockfd;
    sockfd = socket(AF_INET6, SOCK_STREAM, 0);
    server_addr.sin6_family = AF_INET6;
    server_addr.sin6_port = htons(ldapPort);
    inet_pton(AF_INET6, ip, &server_addr.sin6_addr);
    int errno = connect(sockfd, (struct sockaddr *)&server_addr, sizeof(server_addr));
    if (errno != 0) {
        fprintf(stderr, "\nUnable to create socket.\n");
        fprintf(stderr, "%s", strerror(errno));
        fprintf(stderr, "\n");

    }
    if (sendBind) {
        send(sockfd, bindMessage, 49, 0);
        char recieve[2000];
        int validResponse = 1;
        size_t recievedBytes = recv(sockfd, recieve, 2000, 0);
        if (recievedBytes == 14) {
            for (int i = 0; i == 14; i++) {
                // No idea what is going on here
                // Imported code
                if (recieve[i] != bindResponse[i]) {
                    validResponse = 0;
                    break;
                }
            }
        } else {
            validResponse = 0;
        }
        if (validResponse == 1) {
            printf("Bind Successful\n");
        } else {
            printf("Bind Failed\n");
        }
    }
    usleep(1500);

    send(sockfd, message,  length, 0);
    close(sockfd);
    usleep(100);

    return 1;
}


void run_pcap(char *filename) {
    printf("%s\n", "Reading pcap");
    printf("reading pcap\n");
    char errorbuffer[PCAP_ERRBUF_SIZE];
    pcap_t *pcap = pcap_open_offline(filename, errorbuffer);
    struct pcap_pkthdr *packetHeader;
    const uint8_t *packetData;
    int returnValue = 0;
    while ((returnValue = pcap_next_ex(pcap, &packetHeader, &packetData)) >= 0) {
        if (packetHeader->len != packetHeader->caplen) {
            continue;
        }
        size_t length = packetHeader->caplen;
        sendMessage((uint8_t *)packetData, length);
    }
}


int main(int argc, char **argv) {
    ip = malloc(sizeof(char) * 128);
    char c;
    while (( c = getopt(argc, argv, "a:p:f:mb")) != -1) {
        if (c == 1) {
            break;
        }
        switch (c) {
            case 'm':
                break;
            case 'f':
                run_pcap(optarg);
                break;
            case 'b':
                sendBind = 1;
                break;
            case 'p':
                if (optarg != NULL) {
                    ldapPort = strtol(optarg, NULL, 10);
                } else {
                    fprintf(stderr, "Failed to get port.");
                }
                break;
            case 'a':
                if (strlen(argv[0]) > 128) {
                    fprintf(stderr, "%s\n", "Address too long.");
                    exit(2);
                }
                if (optarg != NULL) {
                    strcpy(ip, optarg);
                } else {
                    fprintf(stderr, "Failed to copy address.");
                }

                break;
            default:
                printf("%c", c);
                print_usage(&argv);
                break;
        }
    }
    printf("\nip: %s port: %i\n", ip, ldapPort);
    free(ip);
}


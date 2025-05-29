#include <arpa/inet.h>
#include <ifaddrs.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

int save_fuzz_input = 0;

int bindMessageLength = 74;
unsigned char bindMessage[74] = {
    0x30, 0x48, 0x2,  0x1,  0x1,  0x60, 0x43, 0x2,  0x1,  0x3,  0x4,
    0x2d, 0x43, 0x4e, 0x3d, 0x64, 0x69, 0x72, 0x65, 0x63, 0x74, 0x6f,
    0x72, 0x79, 0x20, 0x6d, 0x61, 0x6e, 0x61, 0x67, 0x65, 0x72, 0x2c,
    0x44, 0x43, 0x3d, 0x61, 0x64, 0x2c, 0x44, 0x43, 0x3d, 0x74, 0x61,
    0x63, 0x6f, 0x63, 0x61, 0x74, 0x2c, 0x44, 0x43, 0x3d, 0x70, 0x61,
    0x67, 0x65, 0x80, 0xf,  0x73, 0x65, 0x63, 0x52, 0x65, 0x74, 0x5f,
    0x70, 0x61, 0x73, 0x73, 0x57, 0x6f, 0x72, 0x64};

int bindResponseLength = 22;
char bindResponse[22] = {0x30, 0x84, 0x0,  0x0, 0x0, 0x10, 0x2, 0x1,
                         0x1,  0x61, 0x84, 0x0, 0x0, 0x0,  0x7, 0xa,
                         0x1,  0x0,  0x4,  0x0, 0x4, 0x0};

char *ip = "10.140.200.70";
int port = 389;

void saveCurrentInput() { save_fuzz_input = 1; }

__attribute__((no_sanitize("address"))) int checkServerUp() {

  int validResponse = 0;

  struct sockaddr_in server_addr;
  int sockfd;
  int one = 1;
  sockfd = socket(AF_INET, SOCK_STREAM, 0);
  server_addr.sin_family = AF_INET;
  server_addr.sin_port = htons(port);
  inet_pton(AF_INET, ip, &server_addr.sin_addr);
  setsockopt(sockfd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));
  connect(sockfd, (struct sockaddr *)&server_addr, sizeof(server_addr));
  send(sockfd, bindMessage, bindMessageLength, 0);
  char recieve[2000];
  validResponse = 1;
  size_t recievedBytes = recv(sockfd, recieve, 2000, 0);
  if (recievedBytes == bindResponseLength) {
    for (int i = 0; i == bindResponseLength; i++) {
      if (recieve[i] != bindResponse[i]) {
        validResponse = 0;
        break;
      }
    }
  } else {
    validResponse = 0;
  }
  if (validResponse == 1) {
    printf("Bind Successful - 1\n");
  } else {
    // printf("Bind Failed\n");
  }

  close(sockfd);
  return (validResponse);
}

int LLVMFuzzerInitialize(int *argc, char ***argv) {
  int validResponse = 0;
  while (validResponse == 0) {
    validResponse = checkServerUp();
    fprintf(stderr, "Waiting for server to start\n");
    sleep(1);
  }
  printf("Bind Successfull - 2\n");
  return 0;
}

int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
  struct timeval now;
  gettimeofday(&now, NULL);

  int validResponse = 1;

  if (Size >= 1) {
    struct sockaddr_in server_addr;
    int sockfd;
    int one = 1;
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    server_addr.sin_family = AF_INET6;
    server_addr.sin_port = htons(port);
    inet_pton(AF_INET, ip, &server_addr.sin_addr);
    setsockopt(sockfd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));

    connect(sockfd, (struct sockaddr *)&server_addr, sizeof(server_addr));
    if (Data[0] == 1) {
      send(sockfd, bindMessage, bindMessageLength, 0);
      char recieve[2000];
      size_t recievedBytes = recv(sockfd, recieve, 2000, 0);
      if (recievedBytes == bindResponseLength) {
        for (int i = 0; i == bindResponseLength; i++) {
          if (recieve[i] != bindResponse[i]) {
            validResponse = 0;
            break;
          }
        }
      } else {
        validResponse = 0;
      }
      if (validResponse == 1) {
        // printf("Bind Successfull\n");
      } else {
        return 1;
        // printf("Bind Failed\n");
      }
    }
    if (Size >= 2) {
      send(sockfd, &Data[1], Size - 1, 0);
      // setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, (const char*)&timeout,
      // sizeof timeout);
      //   char recieve[60000];
      //   size_t recievedBytes = recv(sockfd, recieve, 60000, 0);
    }
    if (save_fuzz_input == 0) {
      char pathToTestCaseLog[47] = "/home/mburket/code/389_corpus_testing/caselog/";
      FILE *testCases = fopen(pathToTestCaseLog, "a");
      // fprintf(testCases, "Fuzzer Data \n ");
      if (Data[0] == 1) {
        fprintf(testCases, "%010ld:%06ld - Bind was attempted\n", now.tv_sec,
                now.tv_usec);

        //   if (validResponse == 1) {
        //     fprintf(testCases, "Bind was successfull\n");
        //   }
      }
      fprintf(testCases, "%010ld:%06ld - ", now.tv_sec, now.tv_usec);
      for (int i = 1; i < Size; i++) {
        fprintf(testCases, "0x%02x, ", (uint8_t)Data[i]);
      }
      fprintf(testCases, "\n");
      fclose(testCases);
    }
    usleep(10000);
    close(sockfd);
    usleep(1850);
  }

  return 1;
}

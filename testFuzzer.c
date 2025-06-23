#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

// Simple fuzz target for demonstration
int fuzzServer(const uint8_t *Data, size_t Size) {
  // Example: parse input as a string and check for a specific pattern
  if (Size == 0) {
    return 0;
  }
  // Simulate some logic to be fuzzed
//   if (Size > 4 && Data[0] == 'T' && Data[1] == 'E' && Data[2] == 'S' &&
//       Data[3] == 'T') {
//     // Simulate a bug if input starts with "TEST"
//     abort();
//   }

  // Otherwise, do nothing
  return 0;
}

void *launchFuzzer2(void *param) {
  char *arg_array[] = {
      "0",
      "/home/admin/software/fuzzing/389ds-test/389-ds-fuzz/corpus",
      "-max_len=65000",
      "-detect_leaks=0",
      "-len_control=20",
      "-rss_limit_mb=20530",
      "-verbosity=4",
      NULL};
  int args_size = 7;
  char **args_ptr = arg_array;
  LLVMFuzzerRunDriver(&args_size, &args_ptr, fuzzServer);
}

void launchFuzzer() {
  pthread_t threadID;
  pthread_create(&threadID, NULL, launchFuzzer2, NULL);
  fprintf(stderr, "fuzzing launched\n");
}

int main(int argc, char **argv) {

  // extern int LLVMFuzzerRunDriver(
  //    int *argc, char ***argv, int (*UserCb)(const uint8_t *Data, size_t
  //    Size));
  launchFuzzer();
  while (1) {
    sleep(1);
  }
}

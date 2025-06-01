#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void mc_event_trigger(char const *span_name) {}
void mc_span_enter(char const *event_name) {}
void mc_span_exit(char const *span_name) {}

void recursive(uint64_t counter) {
  mc_span_enter("recursive");
  printf("recursive: %lu\n", counter);
  mc_event_trigger("recursive");
  if (counter < 2) {
    recursive(counter + 1);
  }
  mc_span_exit("recursive");
}

extern int32_t global;
int32_t global = 789;

int main(void) {
  mc_span_enter("main");

  uint8_t inactive = 0xcc;

  int64_t *heap = malloc(sizeof(int64_t));
  *heap = 456;

  for (int i = 0; i < 2; ++i) {
    uint8_t stack = 123 + i;
    *heap += 2;
    global += 3;
    printf("stack: %d, heap: %li, global: %d\n", stack, *heap, global);
    mc_event_trigger("main_event");

    recursive(0);
    sleep(1);
  }

  mc_span_exit("main");
  free(heap);
  return EXIT_SUCCESS;
}

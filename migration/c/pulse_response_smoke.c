#include "ism_pulse_response.h"
#include "DNS_Migration_PulseResponse.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK(x) do { if (!(x)) { fprintf(stderr, "response C line %d: %s\n", __LINE__, #x); exit(1); } } while (0)
static uint8_t input[65536], saved_input[65536];
static uint8_t output[65541], saved_output[65541];
static unsigned comparisons;

static void compare(uint32_t length, uint32_t capacity, unsigned api, unsigned pattern)
{
  for (size_t i = 0; i < sizeof input; ++i)
    input[i] = (uint8_t)(i * (pattern + 1) * 29 + pattern * 17);
  memcpy(saved_input, input, sizeof input);
  memset(output, 0x79, sizeof output);
  uint32_t expected = length <= 65535 && capacity >= length + 2 ? length + 2 : 0;
  uint32_t actual = api == 0
    ? DNS_Migration_PulseResponse_frame_response(input, output + 1, length, capacity)
    : ism_pulse_response_frame(input, sizeof input, length, output + 1, 65539, capacity);
  CHECK(actual == expected);
  CHECK(memcmp(saved_input, input, sizeof input) == 0);
  for (size_t i = 0; i < 65539; ++i) {
    uint8_t byte = 0x79;
    if (expected != 0 && i < expected)
      byte = i == 0 ? (uint8_t)(length >> 8) : i == 1 ? (uint8_t)length : saved_input[i - 2];
    CHECK(output[i + 1] == byte);
  }
  CHECK(output[0] == 0x79 && output[65540] == 0x79);
  ++comparisons;
}

int main(void)
{
  CHECK(ism_pulse_response_abi_version() == ISM_PULSE_RESPONSE_ABI_VERSION);
  uint32_t lengths[] = {0, 1, 12, 255, 256, 65534, 65535, 65536};
  for (unsigned l = 0; l < sizeof lengths / sizeof lengths[0]; ++l) {
    uint32_t n = lengths[l], capacities[] = {0, 1, n + 1, n + 2, 65539};
    for (unsigned c = 0; c < sizeof capacities / sizeof capacities[0]; ++c)
      for (unsigned api = 0; api < 2; ++api)
        for (unsigned pattern = 0; pattern < 3; ++pattern)
          compare(n, capacities[c], api, pattern);
  }
  /* Invalid descriptors are checked only at the C boundary, never passed to
   * the generated function outside its verified preconditions. */
  memset(input, 0x17, sizeof input); memcpy(saved_input, input, sizeof input);
  memset(output, 0x79, sizeof output); memcpy(saved_output, output, sizeof output);
#define REJECT(call) do { CHECK((call) == 0); \
  CHECK(memcmp(input, saved_input, sizeof input) == 0); \
  CHECK(memcmp(output, saved_output, sizeof output) == 0); } while (0)
  REJECT(ism_pulse_response_frame(NULL, 12, 12, output, sizeof output, 14));
  REJECT(ism_pulse_response_frame(NULL, 1, 0, output, sizeof output, 2));
  REJECT(ism_pulse_response_frame(input, 11, 12, output, sizeof output, 14));
  REJECT(ism_pulse_response_frame(input, sizeof input, UINT32_MAX, output, sizeof output, 14));
  REJECT(ism_pulse_response_frame(input, sizeof input, 12, NULL, 14, 14));
  REJECT(ism_pulse_response_frame(input, sizeof input, 0, NULL, 0, 0));
  REJECT(ism_pulse_response_frame(input, sizeof input, 12, output, 13, 14));
  REJECT(ism_pulse_response_frame(input, sizeof input, 12, input, 14, 14));
  REJECT(ism_pulse_response_frame(input, 12, 12, input + 1, 14, 14));
  REJECT(ism_pulse_response_frame(input + 4, 12, 12, input + 3, 14, 14));
  REJECT(ism_pulse_response_frame(input, 64, 1, input + 32, 10, 3));
  REJECT(ism_pulse_response_frame((uint8_t *)(UINTPTR_MAX - 3), 12, 12, output, 14, 14));
  REJECT(ism_pulse_response_frame(input, 12, 12, (uint8_t *)(UINTPTR_MAX - 3), 14, 14));
  REJECT(ism_pulse_response_frame(input, sizeof input, 12, output, sizeof output, UINT32_MAX));
  CHECK(ism_pulse_response_frame(NULL, 0, 0, output + 1, 4, 2) == 2);
  CHECK(output[0] == 0x79 && output[1] == 0 && output[2] == 0 && output[3] == 0x79);
  /* Adjacent, nonoverlapping borrows from one allocation are valid. */
  CHECK(ism_pulse_response_frame(input, 12, 12, input + 12, 14, 14) == 14);
  CHECK(input[12] == 0 && input[13] == 12 && input[25] == 0x17 && input[26] == 0x17);
  printf("Pulse response C: %u direct/ABI byte comparisons and descriptor checks passed\n", comparisons);
  return 0;
}

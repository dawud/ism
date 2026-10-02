#include "ism_shell.h"
#include "pulse_response_adapter.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void legacy_ism_shell_connection_init(ism_shell_connection *);
DNS_QUIC_StreamMapping_stream_context *legacy_ism_shell_open_stream(ism_shell_connection *, uint64_t);
uint32_t legacy_ism_shell_prepare_doq_response_send(
  ism_shell_connection *, uint64_t, uint8_t *, uint32_t, uint8_t *, uint32_t, bool);

#define CHECK(x) do { if (!(x)) { fprintf(stderr, "response differential line %d: %s\n", __LINE__, #x); exit(1); } } while (0)
static ism_shell_connection baseline, candidate, saved_baseline, saved_candidate;
static uint8_t input[65536], saved_input[65536], old_output[65541], new_output[65541];
static unsigned comparisons;

static void compare(uint64_t id, uint32_t length, uint32_t capacity, bool fin)
{
  memcpy(&saved_baseline, &baseline, sizeof baseline);
  memcpy(&saved_candidate, &candidate, sizeof candidate);
  for (size_t i = 0; i < sizeof input; ++i) input[i] = (uint8_t)(i * 29 + length);
  memcpy(saved_input, input, sizeof input);
  memset(old_output, 0x79, sizeof old_output); memset(new_output, 0x79, sizeof new_output);
  uint32_t old = legacy_ism_shell_prepare_doq_response_send(
    &baseline, id, input, length, old_output + 1, capacity, fin);
  CHECK(memcmp(input, saved_input, sizeof input) == 0);
  uint32_t now = ism_shell_prepare_doq_response_send(
    &candidate, id, input, length, new_output + 1, capacity, fin);
  uint32_t expected = id != 4 && length <= 65535 && capacity >= length + 2 ? length + 2 : 0;
  CHECK(old == expected && now == expected);
  CHECK(memcmp(input, saved_input, sizeof input) == 0);
  CHECK(memcmp(old_output, new_output, sizeof old_output) == 0);
  CHECK(memcmp(&baseline, &saved_baseline, sizeof baseline) == 0);
  CHECK(memcmp(&candidate, &saved_candidate, sizeof candidate) == 0);
  for (size_t i = 0; i < 65539; ++i) {
    uint8_t byte = 0x79;
    if (expected && i < expected)
      byte = i == 0 ? (uint8_t)(length >> 8) : i == 1 ? (uint8_t)length : saved_input[i - 2];
    CHECK(new_output[i + 1] == byte);
  }
  CHECK(new_output[0] == 0x79 && new_output[65540] == 0x79);
  ++comparisons;
}

int main(void)
{
  legacy_ism_shell_connection_init(&baseline); ism_shell_connection_init(&candidate);
  CHECK(legacy_ism_shell_open_stream(&baseline, 0) != NULL);
  CHECK(legacy_ism_shell_open_stream(&baseline, UINT64_MAX) != NULL);
  CHECK(ism_shell_open_stream(&candidate, 0) != NULL);
  CHECK(ism_shell_open_stream(&candidate, UINT64_MAX) != NULL);
  DNS_QUIC_StreamMapping_stream_phase phases[] = {
    {.tag = DNS_QUIC_StreamMapping_ReadingLength},
    {.tag = DNS_QUIC_StreamMapping_ReadingLengthHigh, .case_ReadingLengthHigh = 255},
    {.tag = DNS_QUIC_StreamMapping_ReadingMessage, .case_ReadingMessage = {.fst = 256, .snd = 12}},
    {.tag = DNS_QUIC_StreamMapping_AwaitingFin, .case_AwaitingFin = 12},
    {.tag = DNS_QUIC_StreamMapping_Processing, .case_Processing = 12},
    {.tag = DNS_QUIC_StreamMapping_Done}
  };
  uint64_t ids[] = {0, UINT64_MAX, 4};
  uint32_t lengths[] = {0, 1, 12, 255, 256, 65534, 65535, 65536};
  for (unsigned p = 0; p < sizeof phases / sizeof phases[0]; ++p) {
    for (unsigned s = 0; s < 2; ++s) {
      baseline.streams[s].ctx.sc_phase = phases[p]; candidate.streams[s].ctx.sc_phase = phases[p];
      memset(baseline.streams[s].message_buffer, (int)(0x31 + s), ISM_SHELL_STREAM_BUFFER_SIZE);
      memset(candidate.streams[s].message_buffer, (int)(0x31 + s), ISM_SHELL_STREAM_BUFFER_SIZE);
    }
    for (unsigned l = 0; l < sizeof lengths / sizeof lengths[0]; ++l) {
      uint32_t n = lengths[l], capacities[] = {0, 1, n + 1, n + 2, 65539};
      for (unsigned c = 0; c < sizeof capacities / sizeof capacities[0]; ++c)
        for (unsigned id = 0; id < sizeof ids / sizeof ids[0]; ++id)
          for (unsigned fin = 0; fin < 2; ++fin) compare(ids[id], n, capacities[c], fin != 0);
    }
  }
  /* Bad raw descriptors are outside the baseline contract. Check only the
   * adapter's no-write rejection, including overlap with the stable context. */
  memcpy(&saved_candidate, &candidate, sizeof candidate);
  memcpy(saved_input, input, sizeof input);
  memset(new_output, 0x79, sizeof new_output); memcpy(old_output, new_output, sizeof new_output);
  DNS_QUIC_StreamMapping_stream_context *ctx = &candidate.streams[0].ctx;
#define REJECT(call) do { CHECK((call) == 0); \
  CHECK(memcmp(&candidate, &saved_candidate, sizeof candidate) == 0); \
  CHECK(memcmp(input, saved_input, sizeof input) == 0); \
  CHECK(memcmp(new_output, old_output, sizeof new_output) == 0); } while (0)
  REJECT(ism_pulse_prepare_doq_response(NULL, input, 12, new_output, 14, 1));
  REJECT(ism_pulse_prepare_doq_response(ctx, input, 12, (uint8_t *)ctx, 14, 1));
  REJECT(ism_pulse_prepare_doq_response(ctx, input, 12, (uint8_t *)ctx + 1, 14, 1));
  REJECT(ism_pulse_prepare_doq_response(ctx, input, 12, input + 1, 14, 1));
  REJECT(ism_pulse_prepare_doq_response(ctx, NULL, 12, new_output, 14, 1));
  REJECT(ism_pulse_prepare_doq_response(ctx, input, 12, NULL, 14, 1));
  REJECT(ism_pulse_prepare_doq_response(ctx, input, 12, (uint8_t *)(UINTPTR_MAX - 3), 14, 1));
  REJECT(ism_pulse_prepare_doq_response(ctx, (uint8_t *)(UINTPTR_MAX - 3), 12, new_output, 14, 1));
  CHECK(ism_pulse_prepare_doq_response(ctx, input, 12, new_output + 1, 14, 255) == 14);
  CHECK(new_output[0] == 0x79 && new_output[1] == 0 && new_output[2] == 12 && new_output[15] == 0x79);
  CHECK(memcmp(&candidate, &saved_candidate, sizeof candidate) == 0);
  printf("Pulse/baseline shell response differential: %u comparisons and rejection checks passed\n", comparisons);
  return 0;
}

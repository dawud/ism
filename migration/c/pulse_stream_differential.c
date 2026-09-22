#include "pulse_stream_adapter.h"

#include <stdio.h>
#include <string.h>

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "Pulse/Low* differential failed at line %d\n", __LINE__); return 1; } } while (0)

static uint8_t old_bytes[65535], new_bytes[65535], input[65538], saved[65538];

static bool equal_phase(DNS_QUIC_StreamMapping_stream_phase a,
                        DNS_QUIC_StreamMapping_stream_phase b)
{
  if (a.tag != b.tag) return false;
  switch (a.tag) {
    case DNS_QUIC_StreamMapping_ReadingLengthHigh:
      return a.case_ReadingLengthHigh == b.case_ReadingLengthHigh;
    case DNS_QUIC_StreamMapping_ReadingMessage:
      return a.case_ReadingMessage.fst == b.case_ReadingMessage.fst &&
             a.case_ReadingMessage.snd == b.case_ReadingMessage.snd;
    case DNS_QUIC_StreamMapping_AwaitingFin:
      return a.case_AwaitingFin == b.case_AwaitingFin;
    case DNS_QUIC_StreamMapping_Processing:
      return a.case_Processing == b.case_Processing;
    default:
      return true;
  }
}

int main(void)
{
  DNS_QUIC_StreamMapping_stream_phase states[] = {
    {.tag = DNS_QUIC_StreamMapping_ReadingLength},
    {.tag = DNS_QUIC_StreamMapping_ReadingLengthHigh, .case_ReadingLengthHigh = 0},
    {.tag = DNS_QUIC_StreamMapping_ReadingLengthHigh, .case_ReadingLengthHigh = 255},
    {.tag = DNS_QUIC_StreamMapping_ReadingMessage, .case_ReadingMessage = {12, 0}},
    {.tag = DNS_QUIC_StreamMapping_ReadingMessage, .case_ReadingMessage = {12, 5}},
    {.tag = DNS_QUIC_StreamMapping_ReadingMessage, .case_ReadingMessage = {12, 11}},
    {.tag = DNS_QUIC_StreamMapping_ReadingMessage, .case_ReadingMessage = {12, 12}},
    {.tag = DNS_QUIC_StreamMapping_ReadingMessage, .case_ReadingMessage = {12, 13}},
    {.tag = DNS_QUIC_StreamMapping_ReadingMessage, .case_ReadingMessage = {11, 0}},
    {.tag = DNS_QUIC_StreamMapping_ReadingMessage, .case_ReadingMessage = {65535, 65534}},
    {.tag = DNS_QUIC_StreamMapping_ReadingMessage, .case_ReadingMessage = {65535, UINT32_MAX}},
    {.tag = DNS_QUIC_StreamMapping_AwaitingFin, .case_AwaitingFin = 12},
    {.tag = DNS_QUIC_StreamMapping_AwaitingFin, .case_AwaitingFin = 0},
    {.tag = DNS_QUIC_StreamMapping_AwaitingFin, .case_AwaitingFin = 65535},
    {.tag = DNS_QUIC_StreamMapping_Processing, .case_Processing = 12},
    {.tag = DNS_QUIC_StreamMapping_Processing, .case_Processing = 0},
    {.tag = DNS_QUIC_StreamMapping_Done},
  };
  uint32_t lengths[] = {0, 1, 2, 5, 7, 12, 13, 14, 15, 65535, 65537, 65538};
  uint8_t prefixes[][2] = {{0, 0}, {0, 11}, {0, 12}, {0, 255}, {255, 255}};
  unsigned comparisons = 0;
  for (size_t s = 0; s < sizeof states / sizeof states[0]; ++s) {
    for (size_t p = 0; p < sizeof prefixes / sizeof prefixes[0]; ++p) {
      for (size_t n = 0; n < sizeof lengths / sizeof lengths[0]; ++n) {
        memset(old_bytes, 0x79, sizeof old_bytes);
        memset(new_bytes, 0x79, sizeof new_bytes);
        memset(input, 0xa5, sizeof input);
        input[0] = prefixes[p][0]; input[1] = prefixes[p][1];
        memcpy(saved, input, sizeof input);
        DNS_QUIC_StreamMapping_stream_context old = {7, states[s], old_bytes};
        DNS_QUIC_StreamMapping_stream_context candidate = {7, states[s], new_bytes};
        uint8_t expected = DNS_ShellBoundary_dispatch_authenticated_stream_data(&old, 7, input, lengths[n]);
        CHECK(ism_pulse_ingress_data(&candidate, 7, input, lengths[n]) == expected);
        CHECK(equal_phase(old.sc_phase, candidate.sc_phase));
        CHECK(candidate.sc_id == 7 && candidate.sc_buf == new_bytes);
        CHECK(memcmp(old_bytes, new_bytes, sizeof old_bytes) == 0);
        CHECK(memcmp(input, saved, sizeof input) == 0);
        ++comparisons;
      }
    }
    for (unsigned id = 0; id < 3; ++id) {
      memset(old_bytes, 0, sizeof old_bytes);
      if (id != 0) old_bytes[id - 1] = 1;
      memcpy(new_bytes, old_bytes, sizeof old_bytes);
      DNS_QUIC_StreamMapping_stream_context old = {7, states[s], old_bytes};
      DNS_QUIC_StreamMapping_stream_context candidate = {7, states[s], new_bytes};
      CHECK(ism_pulse_ingress_fin(&candidate) == DNS_ShellBoundary_dispatch_authenticated_stream_fin(&old));
      CHECK(equal_phase(old.sc_phase, candidate.sc_phase));
      CHECK(memcmp(old_bytes, new_bytes, sizeof old_bytes) == 0);
      ++comparisons;
    }
  }
  /* These raw states are outside the old generated contract: do not call it. */
  DNS_QUIC_StreamMapping_stream_context invalid = {7, {.tag = 99}, new_bytes};
  CHECK(ism_pulse_ingress_data(&invalid, 7, input, 14) == 3);
  CHECK(invalid.sc_phase.tag == DNS_QUIC_StreamMapping_Done && invalid.sc_id == 7);
  invalid.sc_phase = (DNS_QUIC_StreamMapping_stream_phase){
    .tag = DNS_QUIC_StreamMapping_AwaitingFin, .case_AwaitingFin = 65536};
  CHECK(ism_pulse_ingress_fin(&invalid) == 3);
  CHECK(invalid.sc_phase.tag == DNS_QUIC_StreamMapping_Done);
  invalid.sc_phase = states[0];
  CHECK(ism_pulse_ingress_data(&invalid, 8, input, 14) == 3 && invalid.sc_id == 7);
  printf("Pulse/Low* differential: %u state/byte/FIN comparisons passed\n", comparisons);
  return 0;
}

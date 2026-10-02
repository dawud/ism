#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "DNS_ShellResponseBoundary.h"

/* Stable generated framing only: the Pulse response port is proof-only.
 * Every call satisfies the live, separate buffers and truthful lengths assumed
 * by the F* wrapper, including rejected requests. Do not pass UINT32_MAX as a
 * source length here: that arithmetic edge is covered by the pure proof tests. */
static bool framing_regressions(void)
{
  static uint8_t input[65536];
  static uint8_t guarded_output[65541];
  const uint32_t lengths[] = {0, 1, 12, 255, 256, 65534, 65535, 65536};
  const uint8_t fin_codes[] = {0, 1, 255};
  uint8_t *output = guarded_output + 1;
  DNS_QUIC_StreamMapping_stream_context context = {
    .sc_id = UINT64_MAX,
    .sc_phase = {
      .tag = DNS_QUIC_StreamMapping_Processing,
      .case_Processing = 12
    },
    .sc_buf = input
  };

  for (size_t l = 0; l < sizeof(lengths) / sizeof(lengths[0]); ++l) {
    uint32_t length = lengths[l];
    const uint32_t capacities[] = {0, 1, length + 1, length + 2, 65539};
    for (size_t c = 0; c < sizeof(capacities) / sizeof(capacities[0]); ++c) {
      uint32_t capacity = capacities[c];
      uint32_t expected = length <= UINT16_MAX && capacity >= length + 2
        ? length + 2 : 0;
      for (size_t f = 0; f < sizeof(fin_codes) / sizeof(fin_codes[0]); ++f) {
        for (size_t i = 0; i < sizeof(input); ++i)
          input[i] = (uint8_t)(i * 29u + 17u);
        for (size_t i = 0; i < sizeof(guarded_output); ++i)
          guarded_output[i] = 0x79;

        uint32_t result = DNS_ShellResponseBoundary_prepare_doq_response_send_for_stream(
          &context, input, length, output, capacity, fin_codes[f]);
        if (result != expected || context.sc_id != UINT64_MAX ||
            context.sc_phase.tag != DNS_QUIC_StreamMapping_Processing ||
            context.sc_phase.case_Processing != 12 || context.sc_buf != input)
          return false;
        for (size_t i = 0; i < sizeof(input); ++i)
          if (input[i] != (uint8_t)(i * 29u + 17u))
            return false;
        for (size_t i = 0; i < 65539; ++i) {
          uint8_t byte = 0x79;
          if (expected != 0 && i < expected) {
            byte = i == 0 ? (uint8_t)(length >> 8)
              : i == 1 ? (uint8_t)length : (uint8_t)((i - 2) * 29u + 17u);
          }
          if (output[i] != byte)
            return false;
        }
        if (guarded_output[0] != 0x79 || guarded_output[65540] != 0x79)
          return false;
      }
    }
  }
  return true;
}

bool ism_smoke_shell_response_boundary(void)
{
  uint32_t
  (*prepare)(
    DNS_QUIC_StreamMapping_stream_context *ctx_ptr,
    uint8_t *response_buffer,
    uint32_t response_len,
    uint8_t fin_code
  ) = DNS_ShellResponseBoundary_prepare_response_send_for_stream;
  uint8_t
  (*complete)(
    DNS_QUIC_Multiplexer_connection_context *conn,
    uint8_t *response_buffer,
    uint32_t response_len,
    uint64_t stream_id,
    uint8_t outcome_code
  ) = DNS_ShellResponseBoundary_complete_response_send_for_stream;

  return prepare != 0 && complete != 0 && framing_regressions();
}

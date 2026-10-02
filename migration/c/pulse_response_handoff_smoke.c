/* Test-only observer replacing the stable descriptor function in this binary.
 * The runtime/differential gates link the real stable descriptor implementation.
 * This test links the actual adapter and extracted Pulse archive, not mock copy
 * code, so it checks the exact context, pointer, length and FIN handoff. */
#include "pulse_response_adapter.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK(x) do { if (!(x)) { fprintf(stderr, "response handoff line %d: %s\n", __LINE__, #x); exit(1); } } while (0)
static uint8_t input[12], output[19];
static DNS_QUIC_StreamMapping_stream_context context;
static unsigned calls;
static uint8_t expected_fin;
static uint32_t expected_length;

uint32_t DNS_ShellResponseBoundary_prepare_response_send_for_stream(
  DNS_QUIC_StreamMapping_stream_context *ctx, uint8_t *data, uint32_t length, uint8_t fin)
{
  CHECK(ctx == &context && ctx->sc_id == UINT64_MAX && ctx->sc_buf == input);
  CHECK(data == output + 1 && length == expected_length && fin == expected_fin);
  CHECK(data[0] == 0 && data[1] == expected_length - 2);
  CHECK(memcmp(data + 2, input, length - 2) == 0);
  ++calls;
  return length;
}

int main(void)
{
  context = (DNS_QUIC_StreamMapping_stream_context){
    .sc_id = UINT64_MAX, .sc_phase = {.tag = DNS_QUIC_StreamMapping_Processing,
      .case_Processing = 12}, .sc_buf = input};
  uint8_t fin_codes[] = {0, 1, 255};
  for (unsigned f = 0; f < sizeof fin_codes; ++f) {
    for (unsigned empty = 0; empty < 2; ++empty) {
      uint32_t length = empty ? 0 : sizeof input;
      expected_fin = fin_codes[f]; expected_length = length + 2;
      memset(input, 0xa5, sizeof input); memset(output, 0x79, sizeof output);
      unsigned before = calls;
      CHECK(ism_pulse_prepare_doq_response(&context, input, length, output + 1,
                                           expected_length, expected_fin) == expected_length);
      CHECK(calls == before + 1 && output[0] == 0x79 && output[expected_length + 1] == 0x79);
      memset(output, 0x79, sizeof output);
      CHECK(ism_pulse_prepare_doq_response(&context, input, length, output + 1,
                                           expected_length - 1, expected_fin) == 0);
      CHECK(calls == before + 1);
      for (unsigned i = 0; i < sizeof output; ++i) CHECK(output[i] == 0x79);
      for (unsigned i = 0; i < sizeof input; ++i) CHECK(input[i] == 0xa5);
      CHECK(context.sc_id == UINT64_MAX && context.sc_buf == input &&
            context.sc_phase.tag == DNS_QUIC_StreamMapping_Processing &&
            context.sc_phase.case_Processing == 12);
    }
  }
  context.sc_buf = NULL;
  CHECK(ism_pulse_prepare_doq_response(&context, input, 12, output + 1, 14, 1) == 0);
  CHECK(calls == 6 && context.sc_buf == NULL);
  for (unsigned i = 0; i < sizeof output; ++i) CHECK(output[i] == 0x79);
  puts("Pulse response adapter handoff: context, pointer, length, FIN and rejection checks passed");
  return 0;
}

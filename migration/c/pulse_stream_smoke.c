#include "ism_pulse_stream.h"

#include <stdio.h>
#include <string.h>

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "Pulse C smoke failed at line %d\n", __LINE__); return 1; } } while (0)

static uint8_t storage[ISM_PULSE_MESSAGE_CAPACITY + 2U];
static uint8_t large_input[ISM_PULSE_MESSAGE_CAPACITY + 3U];

int main(void)
{
  uint8_t *message = storage + 1;
  uint8_t query[14] = {0, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xa5};
  const ism_pulse_phase initial = { .tag = ISM_PULSE_LENGTH };
  CHECK(ism_pulse_stream_abi_version() == ISM_PULSE_STREAM_ABI_VERSION);
  for (uint32_t split = 0; split <= sizeof query; ++split) {
    memset(storage, 0xff, sizeof storage);
    ism_pulse_result a = ism_pulse_stream_data(initial, 7, message,
      ISM_PULSE_MESSAGE_CAPACITY, query, sizeof query, split);
    ism_pulse_result b = ism_pulse_stream_data(a.phase, 7, message,
      ISM_PULSE_MESSAGE_CAPACITY, query + split, sizeof query - split, sizeof query - split);
    CHECK(b.code == 4 && b.phase.tag == ISM_PULSE_AWAITING_FIN && b.phase.expected == 12);
    CHECK(memcmp(message, query + 2, 12) == 0 && message[12] == 0xff);
    CHECK(storage[0] == 0xff && storage[sizeof storage - 1] == 0xff);
    ism_pulse_result fin = ism_pulse_stream_fin(b.phase, 7, message, ISM_PULSE_MESSAGE_CAPACITY);
    CHECK(fin.code == 2 && fin.phase.tag == ISM_PULSE_PROCESSING && fin.phase.expected == 12);
    CHECK(ism_pulse_stream_fin(fin.phase, 7, message, ISM_PULSE_MESSAGE_CAPACITY).code == 2);
    CHECK(memcmp(message, query + 2, 12) == 0 && query[13] == 0xa5);
  }
  for (uint32_t cut = 0; cut < sizeof query; ++cut) {
    memset(storage, 0, sizeof storage);
    ism_pulse_result a = ism_pulse_stream_data(initial, 7, message,
      ISM_PULSE_MESSAGE_CAPACITY, query, sizeof query, cut);
    CHECK(ism_pulse_stream_fin(a.phase, 7, message, ISM_PULSE_MESSAGE_CAPACITY).code == 3);
  }
  uint8_t excess[15];
  memcpy(excess, query, sizeof query);
  excess[14] = 0x79;
  for (uint32_t split = 0; split <= sizeof excess; ++split) {
    memset(storage, 0xff, sizeof storage);
    ism_pulse_result a = ism_pulse_stream_data(initial, 7, message,
      ISM_PULSE_MESSAGE_CAPACITY, excess, sizeof excess, split);
    ism_pulse_result b = ism_pulse_stream_data(a.phase, 7, message,
      ISM_PULSE_MESSAGE_CAPACITY, excess + split, sizeof excess - split, sizeof excess - split);
    CHECK(b.code == 3 && b.phase.tag == ISM_PULSE_DONE && message[12] == 0xff);
    CHECK(ism_pulse_stream_fin(b.phase, 7, message, ISM_PULSE_MESSAGE_CAPACITY).code == 3);
  }
  for (uint8_t length = 0; length < 12; ++length) {
    uint8_t short_prefix[] = {0, length};
    CHECK(ism_pulse_stream_data(initial, 7, message, ISM_PULSE_MESSAGE_CAPACITY,
      short_prefix, sizeof short_prefix, 2).code == 3);
  }
  memset(storage, 0, sizeof storage);
  for (unsigned i = 0; i < 2; ++i) {
    message[i] = 1;
    CHECK(ism_pulse_stream_fin((ism_pulse_phase){.tag = ISM_PULSE_AWAITING_FIN, .expected = 12},
      7, message, ISM_PULSE_MESSAGE_CAPACITY).code == 3);
    message[i] = 0;
  }
  /* Preserve the M2 typed-state policy, not a new blanket validity sanitizer. */
  CHECK(ism_pulse_stream_fin((ism_pulse_phase){.tag = ISM_PULSE_AWAITING_FIN},
    7, message, ISM_PULSE_MESSAGE_CAPACITY).code == 2);
  CHECK(ism_pulse_stream_data((ism_pulse_phase){.tag = ISM_PULSE_BODY, .expected = 12, .current = 13},
    7, message, ISM_PULSE_MESSAGE_CAPACITY, NULL, 0, 0).code == 3);
  CHECK(ism_pulse_stream_data((ism_pulse_phase){.tag = ISM_PULSE_DONE},
    7, message, ISM_PULSE_MESSAGE_CAPACITY, query, sizeof query, sizeof query).code == 3);
  CHECK(message[0] == 0 && message[11] == 0);
  /* Invalid raw ABI states and invalid borrow descriptors fail before access. */
  CHECK(ism_pulse_stream_data((ism_pulse_phase){.tag = 99},
    7, message, ISM_PULSE_MESSAGE_CAPACITY, query, sizeof query, sizeof query).code == 3);
  CHECK(ism_pulse_stream_data((ism_pulse_phase){.tag = ISM_PULSE_BODY, .expected = 65536},
    7, message, ISM_PULSE_MESSAGE_CAPACITY, query, sizeof query, sizeof query).code == 3);
  CHECK(ism_pulse_stream_data(initial, 7, message, ISM_PULSE_MESSAGE_CAPACITY,
    query, sizeof query, UINT32_MAX).code == 3);
  CHECK(ism_pulse_stream_data(initial, 7, message, ISM_PULSE_MESSAGE_CAPACITY,
    NULL, 1, 1).code == 3);
  CHECK(ism_pulse_stream_data(initial, 7, message, 65534, query, sizeof query, 14).code == 3);
  CHECK(ism_pulse_stream_data(initial, 7, NULL, 65535, query, sizeof query, 14).code == 3);
  CHECK(ism_pulse_stream_data(initial, 7, message, ISM_PULSE_MESSAGE_CAPACITY,
    message, 14, 14).code == 3);
  CHECK(ism_pulse_stream_data(initial, 7, message, ISM_PULSE_MESSAGE_CAPACITY,
    message + 1, 14, 14).code == 3);
  CHECK(ism_pulse_stream_fin(initial, 7, message, 1).code == 3);
  CHECK(message[0] == 0 && message[11] == 0);
  CHECK(ism_pulse_stream_data(initial, 7, message, ISM_PULSE_MESSAGE_CAPACITY,
    NULL, 0, 0).phase.tag == ISM_PULSE_LENGTH);
  memset(storage, 0x79, sizeof storage);
  memset(large_input, 0, sizeof large_input);
  large_input[0] = large_input[1] = 255;
  large_input[65536] = 0xa5;
  ism_pulse_result maximum = ism_pulse_stream_data(initial, UINT64_MAX, message,
    ISM_PULSE_MESSAGE_CAPACITY, large_input, sizeof large_input, 65537);
  CHECK(maximum.code == 4 && maximum.phase.expected == 65535);
  CHECK(message[65534] == 0xa5 && storage[0] == 0x79 && storage[65536] == 0x79);
  CHECK(ism_pulse_stream_fin(maximum.phase, UINT64_MAX, message, ISM_PULSE_MESSAGE_CAPACITY).code == 2);
  CHECK(ism_pulse_stream_data(initial, 7, message, ISM_PULSE_MESSAGE_CAPACITY,
    large_input, sizeof large_input, 65538).code == 3);
  puts("Pulse stream C: framing, FIN, copying, ABI and invalid-descriptor checks passed");
  return 0;
}

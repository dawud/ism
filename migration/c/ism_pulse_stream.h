#ifndef ISM_PULSE_STREAM_H
#define ISM_PULSE_STREAM_H

#include <stddef.h>
#include <stdint.h>

/* Versioned, toolchain-neutral C ABI. These are NOT generated enum tag values
   and must be converted by name on each side. No generated types cross here. */
#define ISM_PULSE_STREAM_ABI_VERSION 1U
#define ISM_PULSE_LENGTH 0U
#define ISM_PULSE_LENGTH_HIGH 1U
#define ISM_PULSE_BODY 2U
#define ISM_PULSE_AWAITING_FIN 3U
#define ISM_PULSE_PROCESSING 4U
#define ISM_PULSE_DONE 5U
#define ISM_PULSE_MESSAGE_CAPACITY 65535U

typedef struct ism_pulse_phase_s {
  uint32_t expected;
  uint32_t current;
  uint8_t tag;
  uint8_t high;
} ism_pulse_phase;

typedef struct ism_pulse_result_s {
  ism_pulse_phase phase;
  uint8_t code; /* Existing shell codes: prefix 0, body 1, processing 2,
                   done/error 3, awaiting FIN 4. */
} ism_pulse_result;

uint32_t ism_pulse_stream_abi_version(void);

/* Caller owns live message/input storage of the stated sizes for this call,
   exclusively and without overlap. There is no retained pointer or allocation.
   The input is preserved. An empty fragment uses a local non-null empty borrow.
   Invalid tags, unrepresentable lengths, null/nonempty input, undersized storage
   or overlapping byte ranges return Done/3 without touching message/input.
   This checks descriptors, not allocation provenance, authentication or locks. */
ism_pulse_result ism_pulse_stream_data(
  ism_pulse_phase phase, uint64_t stream_id,
  uint8_t *message, size_t message_capacity,
  uint8_t *input, size_t input_capacity, uint32_t len);

/* FIN needs two live message bytes and never changes them. */
ism_pulse_result ism_pulse_stream_fin(
  ism_pulse_phase phase, uint64_t stream_id,
  uint8_t *message, size_t message_capacity);

#endif

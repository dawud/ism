#include "ism_pulse_stream.h"
#include "DNS_Migration_PulseStream.h"

#include <stdbool.h>

/* Reviewed Linux flat-address ABI. Each translation unit uses only its own
   compiler bundle's generated headers. The manifest also checks the C target. */
_Static_assert(sizeof(size_t) >= sizeof(uint32_t), "M3 requires at least 32-bit size_t");
_Static_assert(sizeof(ism_pulse_phase) == 12 && offsetof(ism_pulse_phase, tag) == 8,
               "unexpected neutral phase ABI");
_Static_assert(sizeof(ism_pulse_result) == 16 && offsetof(ism_pulse_result, code) == 12,
               "unexpected neutral result ABI");

uint32_t ism_pulse_stream_abi_version(void)
{
  return ISM_PULSE_STREAM_ABI_VERSION;
}

static ism_pulse_result rejected(void)
{
  return (ism_pulse_result){ .phase = { .tag = ISM_PULSE_DONE }, .code = 3U };
}

static bool decode(ism_pulse_phase in, DNS_QUIC_StreamModel_stream_phase *out)
{
  *out = (DNS_QUIC_StreamModel_stream_phase){ .tag = DNS_QUIC_StreamModel_Done };
  switch (in.tag) {
    case ISM_PULSE_LENGTH:
      out->tag = DNS_QUIC_StreamModel_ReadingLength;
      return true;
    case ISM_PULSE_LENGTH_HIGH:
      out->tag = DNS_QUIC_StreamModel_ReadingLengthHigh;
      out->case_ReadingLengthHigh = in.high;
      return true;
    case ISM_PULSE_BODY:
      if (in.expected > ISM_PULSE_MESSAGE_CAPACITY) return false;
      out->tag = DNS_QUIC_StreamModel_ReadingMessage;
      out->case_ReadingMessage.expected = in.expected;
      out->case_ReadingMessage.current = in.current;
      return true;
    case ISM_PULSE_AWAITING_FIN:
      if (in.expected > ISM_PULSE_MESSAGE_CAPACITY) return false;
      out->tag = DNS_QUIC_StreamModel_AwaitingFin;
      out->case_AwaitingFin = in.expected;
      return true;
    case ISM_PULSE_PROCESSING:
      if (in.expected > ISM_PULSE_MESSAGE_CAPACITY) return false;
      out->tag = DNS_QUIC_StreamModel_Processing;
      out->case_Processing = in.expected;
      return true;
    case ISM_PULSE_DONE:
      return true;
    default:
      return false;
  }
}

static ism_pulse_result encode(DNS_QUIC_StreamModel_stream_phase in)
{
  ism_pulse_result out = rejected();
  switch (in.tag) {
    case DNS_QUIC_StreamModel_ReadingLength:
      out.phase.tag = ISM_PULSE_LENGTH;
      out.code = 0U;
      break;
    case DNS_QUIC_StreamModel_ReadingLengthHigh:
      out.phase.tag = ISM_PULSE_LENGTH_HIGH;
      out.phase.high = in.case_ReadingLengthHigh;
      out.code = 0U;
      break;
    case DNS_QUIC_StreamModel_ReadingMessage:
      out.phase.tag = ISM_PULSE_BODY;
      out.phase.expected = in.case_ReadingMessage.expected;
      out.phase.current = in.case_ReadingMessage.current;
      out.code = 1U;
      break;
    case DNS_QUIC_StreamModel_AwaitingFin:
      out.phase.tag = ISM_PULSE_AWAITING_FIN;
      out.phase.expected = in.case_AwaitingFin;
      out.code = 4U;
      break;
    case DNS_QUIC_StreamModel_Processing:
      out.phase.tag = ISM_PULSE_PROCESSING;
      out.phase.expected = in.case_Processing;
      out.code = 2U;
      break;
    default:
      break;
  }
  return out;
}

static bool range_ok(const void *p, size_t n)
{
  return p != NULL && n <= UINTPTR_MAX - (uintptr_t)p;
}

static bool disjoint(const void *a, size_t an, const void *b, size_t bn)
{
  uintptr_t ap = (uintptr_t)a, bp = (uintptr_t)b;
  return range_ok(a, an) && range_ok(b, bn) &&
    (ap + an <= bp || bp + bn <= ap);
}

ism_pulse_result ism_pulse_stream_data(
  ism_pulse_phase phase, uint64_t stream_id,
  uint8_t *message, size_t message_capacity,
  uint8_t *input, size_t input_capacity, uint32_t len)
{
  DNS_QUIC_StreamModel_stream_phase decoded;
  if (!decode(phase, &decoded) || message_capacity < ISM_PULSE_MESSAGE_CAPACITY ||
      !range_ok(message, message_capacity) || len > input_capacity) return rejected();
  uint8_t empty = 0U;
  if (len == 0U) {
    input = &empty;
  } else if (!disjoint(message, message_capacity, input, input_capacity)) {
    return rejected();
  }
  /* This local reference is separate from both caller-owned byte arrays.
     The caller must still establish real liveness, truthful capacities and
     exclusive access: raw C cannot manufacture a proved Pulse ownership token. */
  DNS_Migration_PulseStream_stream_context context = {
    .sc_id = stream_id, .sc_phase = decoded, .sc_buf = message
  };
  return encode(DNS_Migration_PulseStream_handle_stream_data(&context, input, len));
}

ism_pulse_result ism_pulse_stream_fin(
  ism_pulse_phase phase, uint64_t stream_id,
  uint8_t *message, size_t message_capacity)
{
  DNS_QUIC_StreamModel_stream_phase decoded;
  if (!decode(phase, &decoded) || message_capacity < 2U ||
      !range_ok(message, message_capacity)) return rejected();
  DNS_Migration_PulseStream_stream_context context = {
    .sc_id = stream_id, .sc_phase = decoded, .sc_buf = message
  };
  return encode(DNS_Migration_PulseStream_handle_stream_fin(&context));
}

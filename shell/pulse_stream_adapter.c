#include "pulse_stream_adapter.h"
#include "ism_pulse_stream.h"

_Static_assert(ISM_SHELL_STREAM_BUFFER_SIZE == ISM_PULSE_MESSAGE_CAPACITY,
               "stream buffer capacity mismatch");
_Static_assert(sizeof(ism_pulse_phase) == 12 && offsetof(ism_pulse_phase, tag) == 8,
               "unexpected neutral phase ABI");
_Static_assert(sizeof(ism_pulse_result) == 16 && offsetof(ism_pulse_result, code) == 12,
               "unexpected neutral result ABI");

static ism_pulse_phase to_wire(DNS_QUIC_StreamMapping_stream_phase in)
{
  ism_pulse_phase out = { .tag = UINT8_MAX };
  switch (in.tag) {
    case DNS_QUIC_StreamMapping_ReadingLength:
      out.tag = ISM_PULSE_LENGTH;
      break;
    case DNS_QUIC_StreamMapping_ReadingLengthHigh:
      out.tag = ISM_PULSE_LENGTH_HIGH;
      out.high = in.case_ReadingLengthHigh;
      break;
    case DNS_QUIC_StreamMapping_ReadingMessage:
      out.tag = ISM_PULSE_BODY;
      out.expected = in.case_ReadingMessage.fst;
      out.current = in.case_ReadingMessage.snd;
      break;
    case DNS_QUIC_StreamMapping_AwaitingFin:
      out.tag = ISM_PULSE_AWAITING_FIN;
      out.expected = in.case_AwaitingFin;
      break;
    case DNS_QUIC_StreamMapping_Processing:
      out.tag = ISM_PULSE_PROCESSING;
      out.expected = in.case_Processing;
      break;
    case DNS_QUIC_StreamMapping_Done:
      out.tag = ISM_PULSE_DONE;
      break;
    default:
      break;
  }
  return out;
}

static DNS_QUIC_StreamMapping_stream_phase from_wire(ism_pulse_phase in)
{
  DNS_QUIC_StreamMapping_stream_phase out = { .tag = DNS_QUIC_StreamMapping_Done };
  switch (in.tag) {
    case ISM_PULSE_LENGTH:
      out.tag = DNS_QUIC_StreamMapping_ReadingLength;
      break;
    case ISM_PULSE_LENGTH_HIGH:
      out.tag = DNS_QUIC_StreamMapping_ReadingLengthHigh;
      out.case_ReadingLengthHigh = in.high;
      break;
    case ISM_PULSE_BODY:
      out.tag = DNS_QUIC_StreamMapping_ReadingMessage;
      out.case_ReadingMessage.fst = in.expected;
      out.case_ReadingMessage.snd = in.current;
      break;
    case ISM_PULSE_AWAITING_FIN:
      out.tag = DNS_QUIC_StreamMapping_AwaitingFin;
      out.case_AwaitingFin = in.expected;
      break;
    case ISM_PULSE_PROCESSING:
      out.tag = DNS_QUIC_StreamMapping_Processing;
      out.case_Processing = in.expected;
      break;
    default:
      break;
  }
  return out;
}

static uint8_t reject(DNS_QUIC_StreamMapping_stream_context *stream)
{
  if (stream != NULL)
    stream->sc_phase = (DNS_QUIC_StreamMapping_stream_phase){ .tag = DNS_QUIC_StreamMapping_Done };
  return 3U;
}

uint8_t ism_pulse_ingress_data(DNS_QUIC_StreamMapping_stream_context *stream,
                             uint64_t stream_id, uint8_t *data, uint32_t len)
{
  if (stream == NULL || stream->sc_id != stream_id ||
      ism_pulse_stream_abi_version() != ISM_PULSE_STREAM_ABI_VERSION) return reject(stream);
  ism_pulse_result result = ism_pulse_stream_data(to_wire(stream->sc_phase), stream_id,
    stream->sc_buf, ISM_SHELL_STREAM_BUFFER_SIZE, data, len, len);
  stream->sc_phase = from_wire(result.phase);
  return result.code;
}

uint8_t ism_pulse_ingress_fin(DNS_QUIC_StreamMapping_stream_context *stream)
{
  if (stream == NULL || ism_pulse_stream_abi_version() != ISM_PULSE_STREAM_ABI_VERSION)
    return reject(stream);
  ism_pulse_result result = ism_pulse_stream_fin(to_wire(stream->sc_phase), stream->sc_id,
    stream->sc_buf, ISM_SHELL_STREAM_BUFFER_SIZE);
  stream->sc_phase = from_wire(result.phase);
  return result.code;
}

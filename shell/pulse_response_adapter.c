#include "pulse_response_adapter.h"
#include "ism_pulse_response.h"
#include "pulse_response_ranges.h"

uint32_t ism_pulse_prepare_doq_response(
  DNS_QUIC_StreamMapping_stream_context *stream,
  uint8_t *response, uint32_t length,
  uint8_t *destination, uint32_t capacity, uint8_t fin_code)
{
  if (ism_pulse_response_abi_version() != ISM_PULSE_RESPONSE_ABI_VERSION ||
      !ism_response_disjoint(stream, sizeof(*stream), destination, capacity) ||
      stream->sc_buf == NULL) return 0U;
  /* The public shell API exposes only the source length and destination
   * capacity. Borrow those prefixes; no candidate generated types cross here. */
  uint32_t framed = ism_pulse_response_frame(response, length, length,
                                            destination, capacity, capacity);
  if (framed == 0U) return 0U;
  /* Preserve the existing descriptor handoff and FIN mapping, not merely its
   * length. Asynchronous submission/completion ownership is not migrated. */
  return DNS_ShellResponseBoundary_prepare_response_send_for_stream(
    stream, destination, framed, fin_code);
}

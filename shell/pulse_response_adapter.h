#ifndef ISM_PULSE_RESPONSE_ADAPTER_H
#define ISM_PULSE_RESPONSE_ADAPTER_H

#include "DNS_ShellResponseBoundary.h"

/* Same live context/response/destination obligations as the stable wrapper;
 * destination must not overlap context or the used response prefix. Caller
 * serializes access and keeps send storage immutable until matching completion.
 * This adapter does not establish that asynchronous lifetime. */
uint32_t ism_pulse_prepare_doq_response(
  DNS_QUIC_StreamMapping_stream_context *stream,
  uint8_t *response, uint32_t length,
  uint8_t *destination, uint32_t capacity, uint8_t fin_code);

#endif

#ifndef ISM_PULSE_STREAM_ADAPTER_H
#define ISM_PULSE_STREAM_ADAPTER_H

#include "ism_shell.h"

/* Same caller-owned shell context and storage as the Low* ingress boundary;
   calls are serialized, and the message buffer has the fixed shell capacity. */
uint8_t ism_pulse_ingress_data(DNS_QUIC_StreamMapping_stream_context *stream,
                             uint64_t stream_id, uint8_t *data, uint32_t len);
uint8_t ism_pulse_ingress_fin(DNS_QUIC_StreamMapping_stream_context *stream);

#endif

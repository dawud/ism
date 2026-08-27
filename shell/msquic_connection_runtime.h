#ifndef ISM_MSQUIC_CONNECTION_RUNTIME_H
#define ISM_MSQUIC_CONNECTION_RUNTIME_H

#include <stdbool.h>
#include <stdint.h>

#include "msquic_runtime.h"

#if ISM_ENABLE_MSQUIC
typedef struct ism_msquic_connection_stream_slot_s
{
  ism_msquic_runtime_stream runtime;
  const QUIC_API_TABLE *api;
  uint8_t *ingress_buffer;
  uint32_t ingress_capacity;
  HQUIC stream;
  bool in_use;
}
ism_msquic_connection_stream_slot;

typedef struct ism_msquic_connection_runtime_s
{
  const QUIC_API_TABLE *api;
  HQUIC configuration;
  ism_msquic_adapter *adapter;
  ism_shell_event_queue *queue;
  ism_msquic_connection_stream_slot *stream_slots;
  uint32_t stream_slot_count;
}
ism_msquic_connection_runtime;

void
ism_msquic_connection_runtime_init(
  ism_msquic_connection_runtime *runtime,
  const QUIC_API_TABLE *api,
  HQUIC configuration,
  ism_msquic_adapter *adapter,
  ism_shell_event_queue *queue,
  ism_msquic_connection_stream_slot *stream_slots,
  uint32_t stream_slot_count
);

void
ism_msquic_connection_stream_slot_init(
  ism_msquic_connection_stream_slot *slot,
  uint8_t *ingress_buffer,
  uint32_t ingress_capacity
);

bool
ism_msquic_connection_runtime_send(
  void *ctx,
  uint64_t stream_id,
  uint8_t *data,
  uint32_t len,
  bool fin
);

QUIC_STATUS QUIC_API
ism_msquic_connection_runtime_listener_callback(
  HQUIC listener,
  void *context,
  QUIC_LISTENER_EVENT *event
);

QUIC_STATUS QUIC_API
ism_msquic_connection_runtime_connection_callback(
  HQUIC connection,
  void *context,
  QUIC_CONNECTION_EVENT *event
);
#endif

#endif /* ISM_MSQUIC_CONNECTION_RUNTIME_H */

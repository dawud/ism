#ifndef ISM_MSQUIC_RUNTIME_H
#define ISM_MSQUIC_RUNTIME_H

#include <stdbool.h>
#include <stdint.h>

#include "ism_event_queue.h"

#if ISM_ENABLE_MSQUIC
#include <msquic.h>
#endif

typedef struct ism_msquic_runtime_buffer_s
{
  uint8_t *data;
  uint32_t len;
}
ism_msquic_runtime_buffer;

typedef struct ism_msquic_runtime_send_context_s
{
  uint32_t response_len;
}
ism_msquic_runtime_send_context;

typedef struct ism_msquic_runtime_stream_s
{
  ism_msquic_adapter *adapter;
  ism_shell_event_queue *queue;
  uint64_t stream_id;
  uint8_t *ingress_buffer;
  uint32_t ingress_capacity;
  bool received_fin;
#if ISM_ENABLE_MSQUIC
  const QUIC_API_TABLE *api;
  HQUIC stream;
  HQUIC connection; /* optional owner, needed for fatal DoQ protocol errors */
  QUIC_BUFFER send_buffer;
  ism_msquic_runtime_send_context send_context;
  bool send_in_flight;
  bool reset_pending;
#endif
}
ism_msquic_runtime_stream;

void
ism_msquic_runtime_stream_init(
  ism_msquic_runtime_stream *runtime,
  ism_msquic_adapter *adapter,
  ism_shell_event_queue *queue,
  uint64_t stream_id,
  uint8_t *ingress_buffer,
  uint32_t ingress_capacity
);

bool
ism_msquic_runtime_on_receive(
  ism_msquic_runtime_stream *runtime,
  const ism_msquic_runtime_buffer *buffers,
  uint32_t buffer_count
);

bool
ism_msquic_runtime_on_fin(ism_msquic_runtime_stream *runtime);

bool
ism_msquic_runtime_on_send_complete(
  ism_msquic_runtime_stream *runtime,
  uint32_t response_len,
  bool dropped
);

bool
ism_msquic_runtime_on_stream_reset(
  ism_msquic_runtime_stream *runtime
);

#if ISM_ENABLE_MSQUIC
void
ism_msquic_runtime_bind_msquic_stream(
  ism_msquic_runtime_stream *runtime,
  const QUIC_API_TABLE *api,
  HQUIC stream
);

bool
ism_msquic_runtime_send(
  void *ctx,
  uint64_t stream_id,
  uint8_t *data,
  uint32_t len,
  bool fin
);

QUIC_STATUS QUIC_API
ism_msquic_runtime_stream_callback(
  HQUIC stream,
  void *context,
  QUIC_STREAM_EVENT *event
);
#endif

#endif /* ISM_MSQUIC_RUNTIME_H */

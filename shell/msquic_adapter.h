#ifndef ISM_MSQUIC_ADAPTER_H
#define ISM_MSQUIC_ADAPTER_H

#include <stdbool.h>
#include <stdint.h>

#include "ism_shell.h"

typedef bool (*ism_msquic_send_fn)(
  void *ctx,
  uint64_t stream_id,
  uint8_t *data,
  uint32_t len,
  bool fin
);

typedef struct ism_msquic_adapter_s
{
  ism_shell_connection connection;
  uint8_t *response_buffer;
  uint32_t response_capacity;
  uint8_t *send_buffer;
  uint32_t send_capacity;
  ism_msquic_send_fn send;
  void *send_ctx;
  bool send_in_flight;
  uint64_t send_stream_id;
  uint32_t send_len;
}
ism_msquic_adapter;

void
ism_msquic_adapter_init(
  ism_msquic_adapter *adapter,
  uint8_t *response_buffer,
  uint32_t response_capacity,
  uint8_t *send_buffer,
  uint32_t send_capacity,
  ism_msquic_send_fn send,
  void *send_ctx
);

uint8_t
ism_msquic_adapter_on_authenticated_stream_bytes(
  ism_msquic_adapter *adapter,
  uint64_t stream_id,
  uint8_t *data,
  uint32_t len
);

uint32_t
ism_msquic_adapter_prepare_ready_response(
  ism_msquic_adapter *adapter,
  uint64_t stream_id
);

bool
ism_msquic_adapter_on_send_complete(
  ism_msquic_adapter *adapter,
  uint64_t stream_id,
  uint32_t response_len,
  bool dropped
);

bool
ism_msquic_adapter_on_stream_reset(
  ism_msquic_adapter *adapter,
  uint64_t stream_id
);

#endif /* ISM_MSQUIC_ADAPTER_H */

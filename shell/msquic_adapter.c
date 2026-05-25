#include "msquic_adapter.h"

#include <stddef.h>
#include <string.h>

void
ism_msquic_adapter_init(
  ism_msquic_adapter *adapter,
  uint8_t *response_buffer,
  uint32_t response_capacity,
  ism_msquic_send_fn send,
  void *send_ctx
)
{
  if (adapter == NULL)
  {
    return;
  }

  memset(adapter, 0, sizeof *adapter);
  ism_shell_connection_init(&adapter->connection);
  adapter->response_buffer = response_buffer;
  adapter->response_capacity = response_capacity;
  adapter->send = send;
  adapter->send_ctx = send_ctx;
}

uint8_t
ism_msquic_adapter_on_authenticated_stream_bytes(
  ism_msquic_adapter *adapter,
  uint64_t stream_id,
  uint8_t *data,
  uint32_t len
)
{
  if (adapter == NULL || data == NULL)
  {
    return 3U;
  }

  uint8_t phase =
    ism_shell_dispatch_authenticated_stream_data(
      &adapter->connection,
      stream_id,
      data,
      len
    );

  if (phase == 2U)
  {
    (void)ism_msquic_adapter_prepare_ready_response(adapter, stream_id);
  }

  return phase;
}

uint32_t
ism_msquic_adapter_prepare_ready_response(
  ism_msquic_adapter *adapter,
  uint64_t stream_id
)
{
  if (adapter == NULL ||
      adapter->response_buffer == NULL ||
      adapter->response_capacity == 0U)
  {
    return 0U;
  }

  uint32_t response_len =
    ism_shell_dispatch_ready_stream(
      &adapter->connection,
      stream_id,
      adapter->response_buffer,
      adapter->response_capacity
    );

  if (response_len > 0U && adapter->send != NULL)
  {
    (void)adapter->send(
      adapter->send_ctx,
      stream_id,
      adapter->response_buffer,
      response_len,
      true
    );
  }

  return response_len;
}

bool
ism_msquic_adapter_on_send_complete(
  ism_msquic_adapter *adapter,
  uint64_t stream_id,
  uint32_t response_len,
  bool dropped
)
{
  if (adapter == NULL ||
      adapter->response_buffer == NULL ||
      adapter->response_capacity == 0U ||
      response_len > adapter->response_capacity)
  {
    return false;
  }

  return
    ism_shell_dispatch_response_send_finished(
      &adapter->connection,
      stream_id,
      adapter->response_buffer,
      response_len,
      dropped
    ) == 1U;
}

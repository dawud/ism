#include "msquic_runtime.h"

#include <stddef.h>
#include <string.h>

void
ism_msquic_runtime_stream_init(
  ism_msquic_runtime_stream *runtime,
  ism_msquic_adapter *adapter,
  ism_shell_event_queue *queue,
  uint64_t stream_id,
  uint8_t *ingress_buffer,
  uint32_t ingress_capacity
)
{
  if (runtime == NULL)
  {
    return;
  }

  runtime->adapter = adapter;
  runtime->queue = queue;
  runtime->stream_id = stream_id;
  runtime->ingress_buffer = ingress_buffer;
  runtime->ingress_capacity = ingress_capacity;
#if ISM_ENABLE_MSQUIC
  runtime->api = NULL;
  runtime->stream = 0;
  runtime->send_buffer = (QUIC_BUFFER){ 0 };
  runtime->send_context = (ism_msquic_runtime_send_context){ 0 };
  runtime->send_in_flight = false;
  runtime->reset_pending = false;
#endif
}

static bool
ism_msquic_runtime_copy_enqueue_and_dispatch(
  ism_msquic_runtime_stream *runtime,
  uint8_t *data,
  uint32_t len
)
{
  if (runtime == NULL ||
      runtime->ingress_buffer == NULL ||
      data == NULL ||
      len > runtime->ingress_capacity)
  {
    return false;
  }

  memcpy(runtime->ingress_buffer, data, len);

  return
    ism_shell_event_queue_enqueue_authenticated_stream_bytes(
      runtime->queue,
      runtime->stream_id,
      runtime->ingress_buffer,
      len
    ) &&
    ism_shell_event_queue_dispatch_one(
      runtime->queue,
      runtime->adapter
    );
}

bool
ism_msquic_runtime_on_receive(
  ism_msquic_runtime_stream *runtime,
  const ism_msquic_runtime_buffer *buffers,
  uint32_t buffer_count
)
{
  if (runtime == NULL ||
      runtime->adapter == NULL ||
      runtime->queue == NULL ||
      (buffers == NULL && buffer_count > 0U))
  {
    return false;
  }

  for (uint32_t i = 0U; i < buffer_count; i++)
  {
    if (buffers[i].len == 0U)
    {
      continue;
    }

    if (buffers[i].data == NULL ||
        !ism_msquic_runtime_copy_enqueue_and_dispatch(
          runtime,
          buffers[i].data,
          buffers[i].len
        ))
    {
      return false;
    }
  }

  return true;
}

bool
ism_msquic_runtime_on_send_complete(
  ism_msquic_runtime_stream *runtime,
  uint32_t response_len,
  bool dropped
)
{
  if (runtime == NULL ||
      runtime->adapter == NULL ||
      runtime->queue == NULL)
  {
    return false;
  }

  return
    ism_shell_event_queue_enqueue_send_complete(
      runtime->queue,
      runtime->stream_id,
      response_len,
      dropped
    ) &&
    ism_shell_event_queue_dispatch_one(
      runtime->queue,
      runtime->adapter
    );
}

bool
ism_msquic_runtime_on_stream_reset(
  ism_msquic_runtime_stream *runtime
)
{
  if (runtime == NULL ||
      runtime->adapter == NULL ||
      runtime->queue == NULL)
  {
    return false;
  }

  return
    ism_shell_event_queue_enqueue_stream_reset(
      runtime->queue,
      runtime->stream_id
    ) &&
    ism_shell_event_queue_dispatch_one(
      runtime->queue,
      runtime->adapter
    );
}

#if ISM_ENABLE_MSQUIC
void
ism_msquic_runtime_bind_msquic_stream(
  ism_msquic_runtime_stream *runtime,
  const QUIC_API_TABLE *api,
  HQUIC stream
)
{
  if (runtime == NULL)
  {
    return;
  }

  runtime->api = api;
  runtime->stream = stream;
}

bool
ism_msquic_runtime_send(
  void *ctx,
  uint64_t stream_id,
  uint8_t *data,
  uint32_t len,
  bool fin
)
{
  ism_msquic_runtime_stream *runtime =
    (ism_msquic_runtime_stream *)ctx;

  if (runtime == NULL ||
      runtime->api == NULL ||
      runtime->api->StreamSend == NULL ||
      runtime->stream == 0 ||
      runtime->stream_id != stream_id ||
      data == NULL ||
      len == 0U ||
      runtime->send_in_flight)
  {
    return false;
  }

  runtime->send_buffer = (QUIC_BUFFER){
    .Length = len,
    .Buffer = data
  };
  runtime->send_context.response_len = len;
  runtime->send_in_flight = true;
  runtime->reset_pending = false;

  QUIC_STATUS status = runtime->api->StreamSend(
    runtime->stream,
    &runtime->send_buffer,
    1U,
    fin ? QUIC_SEND_FLAG_FIN : QUIC_SEND_FLAG_NONE,
    &runtime->send_context
  );

  if (QUIC_FAILED(status))
  {
    runtime->send_buffer = (QUIC_BUFFER){ 0 };
    runtime->send_context.response_len = 0U;
    runtime->send_in_flight = false;
    runtime->reset_pending = false;
    return false;
  }

  return true;
}

static bool
ism_msquic_runtime_on_msquic_receive(
  ism_msquic_runtime_stream *runtime,
  const QUIC_STREAM_EVENT *event
)
{
  if (event == NULL ||
      (event->RECEIVE.Buffers == NULL &&
       event->RECEIVE.BufferCount > 0U))
  {
    return false;
  }

  for (uint32_t i = 0U; i < event->RECEIVE.BufferCount; i++)
  {
    const QUIC_BUFFER *buffer = &event->RECEIVE.Buffers[i];
    if (buffer->Length == 0U)
    {
      continue;
    }

    if (buffer->Buffer == NULL ||
        !ism_msquic_runtime_copy_enqueue_and_dispatch(
          runtime,
          buffer->Buffer,
          buffer->Length
        ))
    {
      return false;
    }
  }

  return true;
}

QUIC_STATUS QUIC_API
ism_msquic_runtime_stream_callback(
  HQUIC stream,
  void *context,
  QUIC_STREAM_EVENT *event
)
{
  (void)stream;

  ism_msquic_runtime_stream *runtime =
    (ism_msquic_runtime_stream *)context;

  if (runtime == NULL || event == NULL)
  {
    return QUIC_STATUS_INVALID_PARAMETER;
  }

  switch (event->Type)
  {
    case QUIC_STREAM_EVENT_START_COMPLETE:
      runtime->stream_id = event->START_COMPLETE.ID;
      return QUIC_STATUS_SUCCESS;

    case QUIC_STREAM_EVENT_RECEIVE:
      return ism_msquic_runtime_on_msquic_receive(runtime, event)
        ? QUIC_STATUS_SUCCESS
        : QUIC_STATUS_INVALID_STATE;

    case QUIC_STREAM_EVENT_SEND_COMPLETE:
    {
      const ism_msquic_runtime_send_context *send_context =
        (const ism_msquic_runtime_send_context *)
          event->SEND_COMPLETE.ClientContext;

      if (send_context == NULL ||
          send_context != &runtime->send_context ||
          !runtime->send_in_flight)
      {
        return QUIC_STATUS_INVALID_PARAMETER;
      }

      uint32_t response_len = send_context->response_len;
      bool dropped = event->SEND_COMPLETE.Canceled != 0 ||
                     runtime->reset_pending;
      runtime->send_buffer = (QUIC_BUFFER){ 0 };
      runtime->send_context.response_len = 0U;
      runtime->send_in_flight = false;
      runtime->reset_pending = false;

      if (!runtime->adapter->send_in_flight)
      {
        return QUIC_STATUS_SUCCESS;
      }

      return
        ism_msquic_runtime_on_send_complete(
          runtime,
          response_len,
          dropped
        )
          ? QUIC_STATUS_SUCCESS
          : QUIC_STATUS_INVALID_STATE;
    }

    case QUIC_STREAM_EVENT_PEER_SEND_ABORTED:
    case QUIC_STREAM_EVENT_PEER_RECEIVE_ABORTED:
    case QUIC_STREAM_EVENT_SHUTDOWN_COMPLETE:
      if (runtime->send_in_flight)
      {
        runtime->reset_pending = true;
        return QUIC_STATUS_SUCCESS;
      }

      return ism_msquic_runtime_on_stream_reset(runtime)
        ? QUIC_STATUS_SUCCESS
        : QUIC_STATUS_INVALID_STATE;

    default:
      return QUIC_STATUS_SUCCESS;
  }
}
#endif

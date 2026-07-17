#include "msquic_connection_runtime.h"

#include <stddef.h>
#include <string.h>

#if ISM_ENABLE_MSQUIC
void
ism_msquic_connection_stream_slot_init(
  ism_msquic_connection_stream_slot *slot,
  uint8_t *ingress_buffer,
  uint32_t ingress_capacity
)
{
  if (slot == NULL)
  {
    return;
  }

  memset(slot, 0, sizeof *slot);
  slot->ingress_buffer = ingress_buffer;
  slot->ingress_capacity = ingress_capacity;
}

void
ism_msquic_connection_runtime_init(
  ism_msquic_connection_runtime *runtime,
  const QUIC_API_TABLE *api,
  HQUIC configuration,
  ism_msquic_adapter *adapter,
  ism_shell_event_queue *queue,
  ism_msquic_connection_stream_slot *stream_slots,
  uint32_t stream_slot_count
)
{
  if (runtime == NULL)
  {
    return;
  }

  runtime->api = api;
  runtime->configuration = configuration;
  runtime->adapter = adapter;
  runtime->queue = queue;
  runtime->stream_slots = stream_slots;
  runtime->stream_slot_count = stream_slot_count;
}

static void
ism_msquic_connection_runtime_release_slot(
  ism_msquic_connection_stream_slot *slot
)
{
  if (slot == NULL)
  {
    return;
  }

  if (slot->api != NULL && slot->stream != 0)
  {
    slot->api->StreamClose(slot->stream);
  }

  slot->api = NULL;
  slot->stream = 0;
  slot->in_use = false;
  ism_msquic_runtime_stream_init(
    &slot->runtime,
    0,
    0,
    0U,
    slot->ingress_buffer,
    slot->ingress_capacity
  );
}

static QUIC_STATUS QUIC_API
ism_msquic_connection_runtime_stream_callback(
  HQUIC stream,
  void *context,
  QUIC_STREAM_EVENT *event
)
{
  ism_msquic_connection_stream_slot *slot =
    (ism_msquic_connection_stream_slot *)context;

  if (slot == NULL || event == NULL)
  {
    return QUIC_STATUS_INVALID_PARAMETER;
  }

  QUIC_STATUS status =
    ism_msquic_runtime_stream_callback(
      stream,
      &slot->runtime,
      event
    );

  if (QUIC_SUCCEEDED(status) &&
      event->Type == QUIC_STREAM_EVENT_SHUTDOWN_COMPLETE)
  {
    ism_msquic_connection_runtime_release_slot(slot);
  }

  return status;
}

static ism_msquic_connection_stream_slot *
ism_msquic_connection_runtime_allocate_slot(
  ism_msquic_connection_runtime *runtime,
  HQUIC stream
)
{
  if (runtime == NULL ||
      runtime->api == NULL ||
      stream == 0)
  {
    return NULL;
  }

  QUIC_UINT62 msquic_stream_id = 0U;
  uint32_t stream_id_len = sizeof msquic_stream_id;
  if (QUIC_FAILED(runtime->api->GetParam(
        stream,
        QUIC_PARAM_STREAM_ID,
        &stream_id_len,
        &msquic_stream_id
      )) ||
      stream_id_len != sizeof msquic_stream_id)
  {
    return NULL;
  }

  for (uint32_t i = 0U; i < runtime->stream_slot_count; i++)
  {
    ism_msquic_connection_stream_slot *slot = &runtime->stream_slots[i];
    if (!slot->in_use &&
        slot->ingress_buffer != NULL &&
        slot->ingress_capacity > 0U)
    {
      ism_msquic_runtime_stream_init(
        &slot->runtime,
        runtime->adapter,
        runtime->queue,
        (uint64_t)msquic_stream_id,
        slot->ingress_buffer,
        slot->ingress_capacity
      );
      slot->api = runtime->api;
      slot->stream = stream;
      slot->in_use = true;
      return slot;
    }
  }

  return NULL;
}

static QUIC_STATUS
ism_msquic_connection_runtime_accept_connection(
  ism_msquic_connection_runtime *runtime,
  HQUIC connection
)
{
  if (runtime == NULL ||
      runtime->api == NULL ||
      runtime->configuration == 0 ||
      connection == 0)
  {
    return QUIC_STATUS_INVALID_PARAMETER;
  }

  runtime->api->SetCallbackHandler(
    connection,
    (void *)ism_msquic_connection_runtime_connection_callback,
    runtime
  );

  return runtime->api->ConnectionSetConfiguration(
    connection,
    runtime->configuration
  );
}

QUIC_STATUS QUIC_API
ism_msquic_connection_runtime_listener_callback(
  HQUIC listener,
  void *context,
  QUIC_LISTENER_EVENT *event
)
{
  (void)listener;

  ism_msquic_connection_runtime *runtime =
    (ism_msquic_connection_runtime *)context;

  if (runtime == NULL || runtime->api == NULL || event == NULL)
  {
    return QUIC_STATUS_INVALID_PARAMETER;
  }

  switch (event->Type)
  {
    case QUIC_LISTENER_EVENT_NEW_CONNECTION:
      return ism_msquic_connection_runtime_accept_connection(
        runtime,
        event->NEW_CONNECTION.Connection
      );

    default:
      return QUIC_STATUS_SUCCESS;
  }
}

QUIC_STATUS QUIC_API
ism_msquic_connection_runtime_connection_callback(
  HQUIC connection,
  void *context,
  QUIC_CONNECTION_EVENT *event
)
{
  (void)connection;

  ism_msquic_connection_runtime *runtime =
    (ism_msquic_connection_runtime *)context;

  if (runtime == NULL || runtime->api == NULL || event == NULL)
  {
    return QUIC_STATUS_INVALID_PARAMETER;
  }

  switch (event->Type)
  {
    case QUIC_CONNECTION_EVENT_PEER_STREAM_STARTED:
    {
      ism_msquic_connection_stream_slot *slot =
        ism_msquic_connection_runtime_allocate_slot(
          runtime,
          event->PEER_STREAM_STARTED.Stream
        );

      if (slot == NULL)
      {
        if (event->PEER_STREAM_STARTED.Stream != 0)
        {
          runtime->api->StreamClose(event->PEER_STREAM_STARTED.Stream);
        }
        return QUIC_STATUS_INVALID_STATE;
      }

      runtime->api->SetCallbackHandler(
        event->PEER_STREAM_STARTED.Stream,
        (void *)ism_msquic_connection_runtime_stream_callback,
        slot
      );

      return QUIC_STATUS_SUCCESS;
    }

    default:
      return QUIC_STATUS_SUCCESS;
  }
}
#endif

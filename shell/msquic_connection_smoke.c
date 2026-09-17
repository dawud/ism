#include "msquic_connection_runtime.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

typedef struct ism_msquic_connection_smoke_state_s
{
  HQUIC connection;
  HQUIC configuration;
  HQUIC stream;
  HQUIC closed_connections[2];
  HQUIC closed_streams[4];
  uint32_t closed_connection_count;
  uint32_t closed_stream_count;
  uint32_t set_callback_count;
  uint32_t get_param_count;
  uint32_t set_configuration_count;
  uint32_t stream_id_len;
  QUIC_UINT62 stream_id;
  void *connection_handler;
  void *connection_context;
  void *stream_handler;
  void *stream_context;
  const QUIC_BUFFER *send_buffers;
  void *send_client_context;
  uint32_t send_buffer_count;
  QUIC_SEND_FLAGS send_flags;
  uint32_t stream_send_count;
  bool get_param_should_fail;
}
ism_msquic_connection_smoke_state;

static ism_msquic_connection_smoke_state *g_smoke_state = NULL;

void
DNSProtocolEverParseError(
  const char *struct_name,
  const char *field_name,
  const char *reason
)
{
  (void)struct_name;
  (void)field_name;
  (void)reason;
}

static HQUIC
smoke_handle(uintptr_t value)
{
  return (HQUIC)value;
}

static uint32_t protocol_shutdowns;
static void QUIC_API
smoke_protocol_shutdown(HQUIC connection, QUIC_CONNECTION_SHUTDOWN_FLAGS flags,
                        QUIC_UINT62 error)
{
  if (connection == smoke_handle(99U) &&
      flags == QUIC_CONNECTION_SHUTDOWN_FLAG_NONE && error == 2U)
  {
    protocol_shutdowns++;
  }
}

static bool
smoke_protocol_errors(void)
{
  static ism_msquic_adapter adapter;
  uint8_t response[64], send[64], ingress[64];
  ism_shell_event events[1];
  ism_shell_event_queue queue;
  ism_msquic_runtime_stream runtime;
  const QUIC_API_TABLE api = { .ConnectionShutdown = smoke_protocol_shutdown };
  uint8_t query[] = {0,17, 0,0,1,0,0,1,0,0,0,0,0,0, 0,0,1,0,1,0xff};
  protocol_shutdowns = 0;
  for (uint32_t scenario = 0; scenario < 4; ++scenario)
  {
    ism_msquic_adapter_init(&adapter,response,sizeof response,send,sizeof send,NULL,NULL);
    ism_shell_event_queue_init(&queue,events,1);
    ism_msquic_runtime_stream_init(&runtime,&adapter,&queue,4,ingress,sizeof ingress);
    ism_msquic_runtime_bind_msquic_stream(&runtime,&api,smoke_handle(98U));
    runtime.connection = smoke_handle(99U);
    query[2] = scenario == 1 ? 1 : 0;
    QUIC_BUFFER buffer = { .Length = scenario == 0 ? 10U : scenario == 2 ? 20U : 19U,
                           .Buffer = query };
    QUIC_STREAM_EVENT event = { .Type = QUIC_STREAM_EVENT_RECEIVE,
      .RECEIVE = { .Buffers = &buffer, .BufferCount = 1,
                  .Flags = scenario == 3 ? QUIC_RECEIVE_FLAG_NONE : QUIC_RECEIVE_FLAG_FIN } };
    QUIC_STATUS status = ism_msquic_runtime_stream_callback(runtime.stream,&runtime,&event);
    if (scenario == 3)
    {
      if (QUIC_FAILED(status)) return false;
      buffer.Buffer = query + 19;
      buffer.Length = 1;
      event.RECEIVE.Flags = QUIC_RECEIVE_FLAG_FIN;
      status = ism_msquic_runtime_stream_callback(runtime.stream,&runtime,&event);
    }
    if (QUIC_SUCCEEDED(status) || protocol_shutdowns != scenario + 1) return false;
  }
  return true;
}

static void QUIC_API
smoke_set_callback_handler(
  HQUIC handle,
  void *handler,
  void *context
)
{
  if (g_smoke_state == NULL)
  {
    return;
  }

  g_smoke_state->set_callback_count++;
  if (handle == g_smoke_state->connection)
  {
    g_smoke_state->connection_handler = handler;
    g_smoke_state->connection_context = context;
  }
  else if (handle == g_smoke_state->stream)
  {
    g_smoke_state->stream_handler = handler;
    g_smoke_state->stream_context = context;
  }
}

static QUIC_STATUS QUIC_API
smoke_get_param(
  HQUIC handle,
  uint32_t param,
  uint32_t *buffer_len,
  void *buffer
)
{
  if (g_smoke_state == NULL ||
      handle != g_smoke_state->stream ||
      param != QUIC_PARAM_STREAM_ID ||
      buffer_len == NULL ||
      buffer == NULL ||
      *buffer_len < sizeof(QUIC_UINT62) ||
      g_smoke_state->get_param_should_fail)
  {
    return QUIC_STATUS_INVALID_PARAMETER;
  }

  g_smoke_state->get_param_count++;
  memcpy(buffer, &g_smoke_state->stream_id, sizeof g_smoke_state->stream_id);
  *buffer_len = g_smoke_state->stream_id_len;
  return QUIC_STATUS_SUCCESS;
}

static QUIC_STATUS QUIC_API
smoke_connection_set_configuration(
  HQUIC connection,
  HQUIC configuration
)
{
  if (g_smoke_state == NULL ||
      connection != g_smoke_state->connection ||
      configuration != g_smoke_state->configuration)
  {
    return QUIC_STATUS_INVALID_PARAMETER;
  }

  g_smoke_state->set_configuration_count++;
  return QUIC_STATUS_SUCCESS;
}

static void QUIC_API
smoke_connection_close(HQUIC connection)
{
  if (g_smoke_state == NULL ||
      g_smoke_state->closed_connection_count >=
        (uint32_t)(sizeof g_smoke_state->closed_connections /
                   sizeof g_smoke_state->closed_connections[0]))
  {
    return;
  }

  g_smoke_state->closed_connections[
    g_smoke_state->closed_connection_count
  ] = connection;
  g_smoke_state->closed_connection_count++;
}

static void QUIC_API
smoke_stream_close(HQUIC stream)
{
  if (g_smoke_state == NULL ||
      g_smoke_state->closed_stream_count >=
        (uint32_t)(sizeof g_smoke_state->closed_streams /
                   sizeof g_smoke_state->closed_streams[0]))
  {
    return;
  }

  g_smoke_state->closed_streams[g_smoke_state->closed_stream_count] = stream;
  g_smoke_state->closed_stream_count++;
}

static QUIC_STATUS QUIC_API
smoke_stream_send(
  HQUIC stream,
  const QUIC_BUFFER *const buffers,
  uint32_t buffer_count,
  QUIC_SEND_FLAGS flags,
  void *client_send_context
)
{
  if (g_smoke_state == NULL ||
      stream != g_smoke_state->stream ||
      buffers == NULL ||
      buffer_count != 1U ||
      buffers[0].Buffer == NULL ||
      buffers[0].Length == 0U ||
      client_send_context == NULL)
  {
    return QUIC_STATUS_INVALID_PARAMETER;
  }

  g_smoke_state->send_buffers = buffers;
  g_smoke_state->send_client_context = client_send_context;
  g_smoke_state->send_buffer_count = buffer_count;
  g_smoke_state->send_flags = flags;
  g_smoke_state->stream_send_count++;
  return QUIC_STATUS_SUCCESS;
}

int
main(void)
{
  const QUIC_API_TABLE api = {
    .SetCallbackHandler = smoke_set_callback_handler,
    .GetParam = smoke_get_param,
    .ConnectionSetConfiguration = smoke_connection_set_configuration,
    .ConnectionClose = smoke_connection_close,
    .StreamClose = smoke_stream_close,
    .StreamSend = smoke_stream_send
  };
  ism_msquic_connection_smoke_state state = {
    .connection = smoke_handle(1U),
    .configuration = smoke_handle(2U),
    .stream = smoke_handle(3U),
    .stream_id_len = sizeof(QUIC_UINT62),
    .stream_id = 41U
  };
  ism_msquic_connection_runtime runtime;
  ism_msquic_connection_stream_slot slots[1];
  ism_msquic_adapter adapter;
  ism_shell_event events[2];
  ism_shell_event_queue queue;
  uint8_t ingress_buffer[64] = { 0U };
  uint8_t response_buffer[128] = { 0U };
  uint8_t send_buffer[128] = { 0U };
  uint8_t exact_a_query[] = {
    0x00U, 0x21U,
    0x00U, 0x00U,
    0x01U, 0x00U,
    0x00U, 0x01U,
    0x00U, 0x00U,
    0x00U, 0x00U,
    0x00U, 0x00U,
    0x03U, 0x77U, 0x77U, 0x77U,
    0x07U, 0x65U, 0x78U, 0x61U, 0x6dU, 0x70U, 0x6cU, 0x65U,
    0x03U, 0x63U, 0x6fU, 0x6dU,
    0x00U,
    0x00U, 0x01U,
    0x00U, 0x01U
  };
  const uint8_t expected_response[] = {
    0x00U, 0x21U,
    0x00U, 0x00U,
    0x81U, 0x00U,
    0x00U, 0x01U,
    0x00U, 0x00U,
    0x00U, 0x00U,
    0x00U, 0x00U,
    0x03U, 0x77U, 0x77U, 0x77U,
    0x07U, 0x65U, 0x78U, 0x61U, 0x6dU, 0x70U, 0x6cU, 0x65U,
    0x03U, 0x63U, 0x6fU, 0x6dU,
    0x00U,
    0x00U, 0x01U,
    0x00U, 0x01U
  };
  const QUIC_BUFFER receive_buffer = {
    .Length = (uint32_t)sizeof exact_a_query,
    .Buffer = exact_a_query
  };
  QUIC_STREAM_EVENT receive_event = {
    .Type = QUIC_STREAM_EVENT_RECEIVE,
    .RECEIVE = {
      .AbsoluteOffset = 0U,
      .TotalBufferLength = sizeof exact_a_query,
      .Buffers = &receive_buffer,
      .BufferCount = 1U,
      .Flags = QUIC_RECEIVE_FLAG_FIN
    }
  };
  QUIC_LISTENER_EVENT listener_event = {
    .Type = QUIC_LISTENER_EVENT_NEW_CONNECTION,
    .NEW_CONNECTION = {
      .Info = NULL,
      .Connection = state.connection
    }
  };
  QUIC_CONNECTION_EVENT stream_event = {
    .Type = QUIC_CONNECTION_EVENT_PEER_STREAM_STARTED,
    .PEER_STREAM_STARTED = {
      .Stream = state.stream,
      .Flags = 0
    }
  };
  QUIC_STREAM_EVENT shutdown_event = {
    .Type = QUIC_STREAM_EVENT_SHUTDOWN_COMPLETE,
    .SHUTDOWN_COMPLETE = {
      .ConnectionShutdown = 1,
      .AppCloseInProgress = 0,
      .ConnectionShutdownByApp = 0,
      .ConnectionClosedRemotely = 1,
      .ConnectionErrorCode = 0U,
      .ConnectionCloseStatus = QUIC_STATUS_SUCCESS
    }
  };
  QUIC_STREAM_EVENT peer_receive_aborted_event = {
    .Type = QUIC_STREAM_EVENT_PEER_RECEIVE_ABORTED,
    .PEER_RECEIVE_ABORTED = {
      .ErrorCode = 1U
    }
  };
  QUIC_CONNECTION_EVENT connection_shutdown_event = {
    .Type = QUIC_CONNECTION_EVENT_SHUTDOWN_COMPLETE,
    .SHUTDOWN_COMPLETE = {
      .HandshakeCompleted = 1,
      .PeerAcknowledgedShutdown = 1,
      .AppCloseInProgress = 0
    }
  };

  g_smoke_state = &state;
  ism_msquic_adapter_init(
    &adapter,
    response_buffer,
    (uint32_t)sizeof response_buffer,
    send_buffer,
    (uint32_t)sizeof send_buffer,
    ism_msquic_connection_runtime_send,
    &runtime
  );
  ism_shell_event_queue_init(
    &queue,
    events,
    (uint32_t)(sizeof events / sizeof events[0])
  );
  ism_msquic_connection_stream_slot_init(
    &slots[0],
    ingress_buffer,
    (uint32_t)sizeof ingress_buffer
  );
  ism_msquic_connection_runtime_init(
    &runtime,
    &api,
    state.configuration,
    &adapter,
    &queue,
    slots,
    (uint32_t)(sizeof slots / sizeof slots[0])
  );

  if (QUIC_FAILED(ism_msquic_connection_runtime_listener_callback(
        smoke_handle(4U),
        &runtime,
        &listener_event
      )) ||
      state.set_callback_count != 1U ||
      state.connection_handler !=
        (void *)ism_msquic_connection_runtime_connection_callback ||
      state.connection_context != &runtime ||
      state.set_configuration_count != 1U)
  {
    return 1;
  }

  if (QUIC_FAILED(ism_msquic_connection_runtime_connection_callback(
        state.connection,
        &runtime,
        &stream_event
      )) ||
      state.get_param_count != 1U ||
      state.set_callback_count != 2U ||
      state.stream_handler == NULL ||
      state.stream_context != &slots[0] ||
      !slots[0].in_use ||
      slots[0].api != &api ||
      slots[0].stream != state.stream ||
      slots[0].runtime.adapter != &adapter ||
      slots[0].runtime.queue != &queue ||
      slots[0].runtime.stream_id != (uint64_t)state.stream_id ||
      slots[0].runtime.ingress_buffer != ingress_buffer ||
      slots[0].runtime.ingress_capacity != (uint32_t)sizeof ingress_buffer)
  {
    return 1;
  }

  QUIC_STREAM_CALLBACK_HANDLER stream_handler =
    (QUIC_STREAM_CALLBACK_HANDLER)state.stream_handler;
  if (QUIC_FAILED(stream_handler(
        state.stream,
        state.stream_context,
        &receive_event
      )) ||
      state.stream_send_count != 1U ||
      state.send_buffers == NULL ||
      state.send_buffer_count != 1U ||
      state.send_buffers[0].Length != (uint32_t)sizeof expected_response ||
      state.send_buffers[0].Buffer != send_buffer ||
      state.send_flags != QUIC_SEND_FLAG_FIN ||
      state.send_client_context != &slots[0].runtime.send_context ||
      !slots[0].runtime.send_in_flight ||
      !adapter.send_in_flight ||
      memcmp(send_buffer, expected_response, sizeof expected_response) != 0)
  {
    return 1;
  }

  QUIC_STREAM_EVENT send_complete_event = {
    .Type = QUIC_STREAM_EVENT_SEND_COMPLETE,
    .SEND_COMPLETE = {
      .Canceled = 0,
      .ClientContext = state.send_client_context
    }
  };
  if (QUIC_FAILED(stream_handler(
        state.stream,
        state.stream_context,
        &send_complete_event
      )) ||
      slots[0].runtime.send_in_flight ||
      adapter.send_in_flight ||
      adapter.connection.ctx.cc_num != 0U)
  {
    return 1;
  }

  if (QUIC_FAILED(stream_handler(
        state.stream,
        state.stream_context,
        &shutdown_event
      )) ||
      slots[0].in_use ||
      slots[0].stream != 0 ||
      slots[0].api != NULL ||
      state.closed_stream_count != 1U ||
      state.closed_streams[0] != state.stream)
  {
    return 1;
  }

  state.stream = smoke_handle(7U);
  state.stream_id = 43U;
  stream_event.PEER_STREAM_STARTED.Stream = state.stream;
  if (QUIC_FAILED(ism_msquic_connection_runtime_connection_callback(
        state.connection,
        &runtime,
        &stream_event
      )))
  {
    return 1;
  }

  stream_handler = (QUIC_STREAM_CALLBACK_HANDLER)state.stream_handler;
  if (QUIC_FAILED(stream_handler(
        state.stream,
        state.stream_context,
        &receive_event
      )) ||
      state.stream_send_count != 2U ||
      !slots[0].runtime.send_in_flight ||
      !adapter.send_in_flight ||
      adapter.connection.ctx.cc_num != 1U)
  {
    return 1;
  }

  if (QUIC_FAILED(stream_handler(
        state.stream,
        state.stream_context,
        &peer_receive_aborted_event
      )) ||
      !slots[0].runtime.send_in_flight ||
      !slots[0].runtime.reset_pending ||
      !adapter.send_in_flight ||
      adapter.connection.ctx.cc_num != 1U)
  {
    return 1;
  }

  send_complete_event.SEND_COMPLETE.Canceled = 1;
  send_complete_event.SEND_COMPLETE.ClientContext = state.send_client_context;
  if (QUIC_FAILED(stream_handler(
        state.stream,
        state.stream_context,
        &send_complete_event
      )) ||
      slots[0].runtime.send_in_flight ||
      slots[0].runtime.reset_pending ||
      adapter.send_in_flight ||
      adapter.connection.ctx.cc_num != 0U)
  {
    return 1;
  }

  if (QUIC_FAILED(stream_handler(
        state.stream,
        state.stream_context,
        &shutdown_event
      )) ||
      slots[0].in_use ||
      state.closed_stream_count != 2U ||
      state.closed_streams[1] != state.stream)
  {
    return 1;
  }

  if (QUIC_FAILED(ism_msquic_connection_runtime_connection_callback(
        state.connection,
        &runtime,
        &connection_shutdown_event
      )) ||
      state.closed_connection_count != 1U ||
      state.closed_connections[0] != state.connection)
  {
    return 1;
  }

  state.stream = smoke_handle(5U);
  stream_event.PEER_STREAM_STARTED.Stream = state.stream;
  slots[0].in_use = true;
  if (ism_msquic_connection_runtime_connection_callback(
        state.connection,
        &runtime,
        &stream_event
      ) != QUIC_STATUS_INVALID_STATE ||
      state.closed_stream_count != 3U ||
      state.closed_streams[2] != state.stream)
  {
    return 1;
  }

  state.stream = smoke_handle(6U);
  state.get_param_should_fail = true;
  stream_event.PEER_STREAM_STARTED.Stream = state.stream;
  slots[0].in_use = false;
  if (ism_msquic_connection_runtime_connection_callback(
        state.connection,
        &runtime,
        &stream_event
      ) != QUIC_STATUS_INVALID_STATE ||
      state.closed_stream_count != 4U ||
      state.closed_streams[3] != state.stream)
  {
    return 1;
  }

  return smoke_protocol_errors() ? 0 : 1;
}

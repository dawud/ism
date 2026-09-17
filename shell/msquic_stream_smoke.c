#include "msquic_runtime.h"

#include <pthread.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

typedef struct ism_msquic_stream_smoke_state_s
{
  pthread_mutex_t lock;
  bool failed;
  bool client_connected;
  bool client_stream_started;
  bool server_new_connection;
  bool server_peer_stream_started;
  bool server_receive_seen;
  bool server_send_complete;
  bool client_response_finished;
  uint32_t server_receive_buffer_count;
  uint64_t server_stream_id;
  uint32_t client_response_len;
  uint8_t client_response[128];
}
ism_msquic_stream_smoke_state;

typedef struct ism_msquic_stream_smoke_server_context_s
{
  const QUIC_API_TABLE *api;
  HQUIC configuration;
  ism_msquic_runtime_stream *stream_runtime;
  ism_msquic_stream_smoke_state *state;
}
ism_msquic_stream_smoke_server_context;

typedef enum ism_msquic_stream_smoke_wait_e
{
  ISM_STREAM_SMOKE_WAIT_CLIENT_CONNECTED,
  ISM_STREAM_SMOKE_WAIT_CLIENT_STREAM_STARTED,
  ISM_STREAM_SMOKE_WAIT_SERVER_RESPONSE
}
ism_msquic_stream_smoke_wait;

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

static void
ism_msquic_stream_smoke_fail(const char *message)
{
  fprintf(stderr, "msquic stream smoke: %s\n", message);
}

static void
ism_msquic_stream_smoke_report_state(
  const ism_msquic_stream_smoke_state *state
)
{
  fprintf(
    stderr,
    "msquic stream smoke state: connected=%u started=%u new_connection=%u "
    "peer_stream=%u receive=%u receive_buffers=%u send_complete=%u "
    "client_response_finished=%u client_response_len=%u\n",
    state->client_connected ? 1U : 0U,
    state->client_stream_started ? 1U : 0U,
    state->server_new_connection ? 1U : 0U,
    state->server_peer_stream_started ? 1U : 0U,
    state->server_receive_seen ? 1U : 0U,
    state->server_receive_buffer_count,
    state->server_send_complete ? 1U : 0U,
    state->client_response_finished ? 1U : 0U,
    state->client_response_len
  );
}

static void
ism_msquic_stream_smoke_set_failed(ism_msquic_stream_smoke_state *state)
{
  pthread_mutex_lock(&state->lock);
  state->failed = true;
  pthread_mutex_unlock(&state->lock);
}

static bool
ism_msquic_stream_smoke_condition_met(
  const ism_msquic_stream_smoke_state *state,
  ism_msquic_stream_smoke_wait condition
)
{
  switch (condition)
  {
    case ISM_STREAM_SMOKE_WAIT_CLIENT_CONNECTED:
      return state->client_connected;
    case ISM_STREAM_SMOKE_WAIT_CLIENT_STREAM_STARTED:
      return state->client_stream_started;
    case ISM_STREAM_SMOKE_WAIT_SERVER_RESPONSE:
      return state->server_send_complete &&
             state->client_response_finished;
    default:
      return false;
  }
}

static bool
ism_msquic_stream_smoke_wait_for(
  ism_msquic_stream_smoke_state *state,
  ism_msquic_stream_smoke_wait condition
)
{
  const struct timespec sleep_time = {
    .tv_sec = 0,
    .tv_nsec = 1000000L
  };

  for (uint32_t i = 0U; i < 10000U; i++)
  {
    bool met = false;
    bool failed = false;

    pthread_mutex_lock(&state->lock);
    failed = state->failed;
    met = ism_msquic_stream_smoke_condition_met(state, condition);
    pthread_mutex_unlock(&state->lock);

    if (failed)
    {
      return false;
    }
    if (met)
    {
      return true;
    }

    nanosleep(&sleep_time, NULL);
  }

  return false;
}

static QUIC_STATUS QUIC_API
ism_msquic_stream_smoke_client_connection_callback(
  HQUIC connection,
  void *context,
  QUIC_CONNECTION_EVENT *event
)
{
  (void)connection;

  ism_msquic_stream_smoke_state *state =
    (ism_msquic_stream_smoke_state *)context;

  if (state == NULL || event == NULL)
  {
    return QUIC_STATUS_INVALID_PARAMETER;
  }

  switch (event->Type)
  {
    case QUIC_CONNECTION_EVENT_CONNECTED:
      pthread_mutex_lock(&state->lock);
      state->client_connected = true;
      pthread_mutex_unlock(&state->lock);
      return QUIC_STATUS_SUCCESS;

    case QUIC_CONNECTION_EVENT_SHUTDOWN_INITIATED_BY_TRANSPORT:
    {
      bool server_send_complete = false;
      pthread_mutex_lock(&state->lock);
      server_send_complete = state->server_send_complete;
      pthread_mutex_unlock(&state->lock);
      if (!server_send_complete)
      {
        ism_msquic_stream_smoke_set_failed(state);
      }
      return QUIC_STATUS_SUCCESS;
    }

    default:
      return QUIC_STATUS_SUCCESS;
  }
}

static QUIC_STATUS QUIC_API
ism_msquic_stream_smoke_client_stream_callback(
  HQUIC stream,
  void *context,
  QUIC_STREAM_EVENT *event
)
{
  (void)stream;

  ism_msquic_stream_smoke_state *state =
    (ism_msquic_stream_smoke_state *)context;

  if (state == NULL || event == NULL)
  {
    return QUIC_STATUS_INVALID_PARAMETER;
  }

  switch (event->Type)
  {
    case QUIC_STREAM_EVENT_START_COMPLETE:
      if (QUIC_FAILED(event->START_COMPLETE.Status))
      {
        ism_msquic_stream_smoke_set_failed(state);
      }
      else
      {
        pthread_mutex_lock(&state->lock);
        state->client_stream_started = true;
        pthread_mutex_unlock(&state->lock);
      }
      return QUIC_STATUS_SUCCESS;

    case QUIC_STREAM_EVENT_SEND_COMPLETE:
      if (event->SEND_COMPLETE.Canceled != 0)
      {
        ism_msquic_stream_smoke_set_failed(state);
      }
      return QUIC_STATUS_SUCCESS;

    case QUIC_STREAM_EVENT_RECEIVE:
      if (event->RECEIVE.Buffers == NULL &&
          event->RECEIVE.BufferCount > 0U)
      {
        ism_msquic_stream_smoke_set_failed(state);
        return QUIC_STATUS_INVALID_PARAMETER;
      }

      pthread_mutex_lock(&state->lock);
      for (uint32_t i = 0U; i < event->RECEIVE.BufferCount; i++)
      {
        const QUIC_BUFFER *buffer = &event->RECEIVE.Buffers[i];
        if (buffer->Buffer == NULL ||
            buffer->Length >
              (uint32_t)sizeof state->client_response -
                state->client_response_len)
        {
          state->failed = true;
          break;
        }

        memcpy(
          state->client_response + state->client_response_len,
          buffer->Buffer,
          buffer->Length
        );
        state->client_response_len += buffer->Length;
      }
      pthread_mutex_unlock(&state->lock);
      return QUIC_STATUS_SUCCESS;

    case QUIC_STREAM_EVENT_PEER_SEND_SHUTDOWN:
      pthread_mutex_lock(&state->lock);
      state->client_response_finished = true;
      pthread_mutex_unlock(&state->lock);
      return QUIC_STATUS_SUCCESS;

    default:
      return QUIC_STATUS_SUCCESS;
  }
}

static QUIC_STATUS QUIC_API
ism_msquic_stream_smoke_server_stream_callback(
  HQUIC stream,
  void *context,
  QUIC_STREAM_EVENT *event
)
{
  ism_msquic_stream_smoke_server_context *server_context =
    (ism_msquic_stream_smoke_server_context *)context;

  if (server_context == NULL ||
      server_context->stream_runtime == NULL ||
      server_context->state == NULL ||
      event == NULL)
  {
    return QUIC_STATUS_INVALID_PARAMETER;
  }

  if (event->Type == QUIC_STREAM_EVENT_RECEIVE)
  {
    pthread_mutex_lock(&server_context->state->lock);
    server_context->state->server_receive_seen = true;
    server_context->state->server_receive_buffer_count +=
      event->RECEIVE.BufferCount;
    pthread_mutex_unlock(&server_context->state->lock);
  }

  QUIC_STATUS status = ism_msquic_runtime_stream_callback(
    stream,
    server_context->stream_runtime,
    event
  );

  if (event->Type == QUIC_STREAM_EVENT_SEND_COMPLETE)
  {
    pthread_mutex_lock(&server_context->state->lock);
    if (QUIC_FAILED(status) || event->SEND_COMPLETE.Canceled != 0)
    {
      server_context->state->failed = true;
    }
    else
    {
      server_context->state->server_send_complete = true;
    }
    pthread_mutex_unlock(&server_context->state->lock);
  }

  if (QUIC_SUCCEEDED(status) &&
      event->Type == QUIC_STREAM_EVENT_SHUTDOWN_COMPLETE)
  {
    server_context->api->StreamClose(stream);
  }

  return status;
}

static QUIC_STATUS QUIC_API
ism_msquic_stream_smoke_server_connection_callback(
  HQUIC connection,
  void *context,
  QUIC_CONNECTION_EVENT *event
)
{
  ism_msquic_stream_smoke_server_context *server_context =
    (ism_msquic_stream_smoke_server_context *)context;

  if (server_context == NULL ||
      server_context->api == NULL ||
      event == NULL)
  {
    return QUIC_STATUS_INVALID_PARAMETER;
  }

  switch (event->Type)
  {
    case QUIC_CONNECTION_EVENT_PEER_STREAM_STARTED:
    {
      QUIC_UINT62 stream_id = 0U;
      uint32_t stream_id_len = sizeof stream_id;
      HQUIC stream = event->PEER_STREAM_STARTED.Stream;

      pthread_mutex_lock(&server_context->state->lock);
      server_context->state->server_peer_stream_started = true;
      pthread_mutex_unlock(&server_context->state->lock);

      if (stream == NULL ||
          QUIC_FAILED(server_context->api->GetParam(
            stream,
            QUIC_PARAM_STREAM_ID,
            &stream_id_len,
            &stream_id
          )) ||
          stream_id_len != sizeof stream_id)
      {
        ism_msquic_stream_smoke_set_failed(server_context->state);
        return QUIC_STATUS_INVALID_STATE;
      }

      server_context->stream_runtime->stream_id = (uint64_t)stream_id;
      pthread_mutex_lock(&server_context->state->lock);
      server_context->state->server_stream_id = (uint64_t)stream_id;
      pthread_mutex_unlock(&server_context->state->lock);
      ism_msquic_runtime_bind_msquic_stream(
        server_context->stream_runtime,
        server_context->api,
        stream
      );
      server_context->api->SetCallbackHandler(
        stream,
        (void *)ism_msquic_stream_smoke_server_stream_callback,
        server_context
      );
      return QUIC_STATUS_SUCCESS;
    }

    case QUIC_CONNECTION_EVENT_SHUTDOWN_COMPLETE:
      if (connection != NULL)
      {
        server_context->api->ConnectionClose(connection);
      }
      return QUIC_STATUS_SUCCESS;

    default:
      return QUIC_STATUS_SUCCESS;
  }
}

static QUIC_STATUS QUIC_API
ism_msquic_stream_smoke_server_listener_callback(
  HQUIC listener,
  void *context,
  QUIC_LISTENER_EVENT *event
)
{
  (void)listener;

  ism_msquic_stream_smoke_server_context *server_context =
    (ism_msquic_stream_smoke_server_context *)context;

  if (server_context == NULL ||
      server_context->api == NULL ||
      event == NULL)
  {
    return QUIC_STATUS_INVALID_PARAMETER;
  }

  switch (event->Type)
  {
    case QUIC_LISTENER_EVENT_NEW_CONNECTION:
      if (event->NEW_CONNECTION.Connection == NULL)
      {
        ism_msquic_stream_smoke_set_failed(server_context->state);
        return QUIC_STATUS_INVALID_PARAMETER;
      }

      pthread_mutex_lock(&server_context->state->lock);
      server_context->state->server_new_connection = true;
      pthread_mutex_unlock(&server_context->state->lock);

      server_context->api->SetCallbackHandler(
        event->NEW_CONNECTION.Connection,
        (void *)ism_msquic_stream_smoke_server_connection_callback,
        server_context
      );
      return server_context->api->ConnectionSetConfiguration(
        event->NEW_CONNECTION.Connection,
        server_context->configuration
      );

    default:
      return QUIC_STATUS_SUCCESS;
  }
}

static bool
ism_msquic_stream_smoke_load_server_credentials(
  const QUIC_API_TABLE *api,
  HQUIC configuration,
  const char *cert_file,
  const char *key_file
)
{
  QUIC_CERTIFICATE_FILE certificate_file = {
    .PrivateKeyFile = key_file,
    .CertificateFile = cert_file
  };
  QUIC_CREDENTIAL_CONFIG credential = {
    .Type = QUIC_CREDENTIAL_TYPE_CERTIFICATE_FILE,
    .Flags = QUIC_CREDENTIAL_FLAG_NONE,
    .CertificateFile = &certificate_file,
    .Principal = NULL,
    .Reserved = NULL,
    .AsyncHandler = NULL,
    .AllowedCipherSuites = QUIC_ALLOWED_CIPHER_SUITE_NONE,
    .CaCertificateFile = NULL
  };

  return QUIC_SUCCEEDED(
    api->ConfigurationLoadCredential(configuration, &credential)
  );
}

static bool
ism_msquic_stream_smoke_load_client_credentials(
  const QUIC_API_TABLE *api,
  HQUIC configuration
)
{
  QUIC_CREDENTIAL_CONFIG credential = {
    .Type = QUIC_CREDENTIAL_TYPE_NONE,
    .Flags = QUIC_CREDENTIAL_FLAG_CLIENT |
             QUIC_CREDENTIAL_FLAG_NO_CERTIFICATE_VALIDATION,
    .CertificateFile = NULL,
    .Principal = NULL,
    .Reserved = NULL,
    .AsyncHandler = NULL,
    .AllowedCipherSuites = QUIC_ALLOWED_CIPHER_SUITE_NONE,
    .CaCertificateFile = NULL
  };

  return QUIC_SUCCEEDED(
    api->ConfigurationLoadCredential(configuration, &credential)
  );
}

int
main(int argc, char **argv)
{
  if (argc != 3)
  {
    return 1;
  }

  const QUIC_API_TABLE *api = NULL;
  HQUIC server_registration = NULL;
  HQUIC client_registration = NULL;
  HQUIC server_configuration = NULL;
  HQUIC client_configuration = NULL;
  HQUIC listener = NULL;
  HQUIC client_connection = NULL;
  HQUIC client_stream = NULL;
  uint8_t alpn_bytes[] = { 'd', 'o', 'q' };
  const QUIC_BUFFER alpn = {
    sizeof alpn_bytes,
    alpn_bytes
  };
  const QUIC_REGISTRATION_CONFIG server_registration_config = {
    "ism-msquic-stream-smoke-server",
    QUIC_EXECUTION_PROFILE_LOW_LATENCY
  };
  const QUIC_REGISTRATION_CONFIG client_registration_config = {
    "ism-msquic-stream-smoke-client",
    QUIC_EXECUTION_PROFILE_LOW_LATENCY
  };
  QUIC_SETTINGS server_settings = { 0 };
  QUIC_ADDR local_address;
  QUIC_ADDR bound_address;
  uint32_t bound_address_len = sizeof bound_address;
  bool listener_started = false;
  int result = 1;

  ism_msquic_stream_smoke_state state = {
    .lock = PTHREAD_MUTEX_INITIALIZER
  };
  ism_msquic_adapter adapter;
  ism_shell_event events[4];
  ism_shell_event_queue queue;
  ism_msquic_runtime_stream server_stream_runtime;
  ism_msquic_stream_smoke_server_context server_context;
  uint8_t ingress_buffer[128] = { 0U };
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
  const QUIC_BUFFER query_buffer = {
    sizeof exact_a_query,
    exact_a_query
  };

  memset(&local_address, 0, sizeof local_address);
  memset(&bound_address, 0, sizeof bound_address);
  QuicAddrSetFamily(&local_address, QUIC_ADDRESS_FAMILY_INET);
  QuicAddrSetToLoopback(&local_address);
  QuicAddrSetPort(&local_address, 0);
  server_settings.IsSet.PeerBidiStreamCount = 1;
  server_settings.PeerBidiStreamCount = 1U;

  if (QUIC_FAILED(MsQuicOpen2(&api)) || api == NULL)
  {
    ism_msquic_stream_smoke_fail("MsQuicOpen2 failed");
    goto cleanup;
  }

  if (QUIC_FAILED(api->RegistrationOpen(
        &server_registration_config,
        &server_registration
      )) ||
      server_registration == NULL ||
      QUIC_FAILED(api->RegistrationOpen(
        &client_registration_config,
        &client_registration
      )) ||
      client_registration == NULL)
  {
    ism_msquic_stream_smoke_fail("registration open failed");
    goto cleanup;
  }

  if (QUIC_FAILED(api->ConfigurationOpen(
        server_registration,
        &alpn,
        1U,
        &server_settings,
        sizeof server_settings,
        NULL,
        &server_configuration
      )) ||
      server_configuration == NULL ||
      QUIC_FAILED(api->ConfigurationOpen(
        client_registration,
        &alpn,
        1U,
        NULL,
        0U,
        NULL,
        &client_configuration
      )) ||
      client_configuration == NULL)
  {
    ism_msquic_stream_smoke_fail("configuration open failed");
    goto cleanup;
  }

  if (!ism_msquic_stream_smoke_load_server_credentials(
        api,
        server_configuration,
        argv[1],
        argv[2]
      ) ||
      !ism_msquic_stream_smoke_load_client_credentials(
        api,
        client_configuration
      ))
  {
    ism_msquic_stream_smoke_fail("credential load failed");
    goto cleanup;
  }

  ism_msquic_adapter_init(
    &adapter,
    response_buffer,
    (uint32_t)sizeof response_buffer,
    send_buffer,
    (uint32_t)sizeof send_buffer,
    ism_msquic_runtime_send,
    &server_stream_runtime
  );
  ism_shell_event_queue_init(
    &queue,
    events,
    (uint32_t)(sizeof events / sizeof events[0])
  );
  ism_msquic_runtime_stream_init(
    &server_stream_runtime,
    &adapter,
    &queue,
    0U,
    ingress_buffer,
    (uint32_t)sizeof ingress_buffer
  );
  server_context = (ism_msquic_stream_smoke_server_context){
    .api = api,
    .configuration = server_configuration,
    .stream_runtime = &server_stream_runtime,
    .state = &state
  };

  if (QUIC_FAILED(api->ListenerOpen(
        server_registration,
        ism_msquic_stream_smoke_server_listener_callback,
        &server_context,
        &listener
      )) ||
      listener == NULL ||
      QUIC_FAILED(api->ListenerStart(listener, &alpn, 1U, &local_address)))
  {
    ism_msquic_stream_smoke_fail("listener open/start failed");
    goto cleanup;
  }
  listener_started = true;

  if (QUIC_FAILED(api->GetParam(
        listener,
        QUIC_PARAM_LISTENER_LOCAL_ADDRESS,
        &bound_address_len,
        &bound_address
      )) ||
      bound_address_len != sizeof bound_address ||
      QuicAddrGetPort(&bound_address) == 0U)
  {
    ism_msquic_stream_smoke_fail("listener local address lookup failed");
    goto cleanup;
  }

  if (QUIC_FAILED(api->ConnectionOpen(
        client_registration,
        ism_msquic_stream_smoke_client_connection_callback,
        &state,
        &client_connection
      )) ||
      client_connection == NULL ||
      QUIC_FAILED(api->ConnectionStart(
        client_connection,
        client_configuration,
        QUIC_ADDRESS_FAMILY_INET,
        "localhost",
        QuicAddrGetPort(&bound_address)
      )))
  {
    ism_msquic_stream_smoke_fail("client connection open/start failed");
    goto cleanup;
  }

  if (!ism_msquic_stream_smoke_wait_for(
        &state,
        ISM_STREAM_SMOKE_WAIT_CLIENT_CONNECTED
      ))
  {
    ism_msquic_stream_smoke_fail("client connection did not connect");
    goto cleanup;
  }

  if (QUIC_FAILED(api->StreamOpen(
        client_connection,
        QUIC_STREAM_OPEN_FLAG_NONE,
        ism_msquic_stream_smoke_client_stream_callback,
        &state,
        &client_stream
      )) ||
      client_stream == NULL)
  {
    ism_msquic_stream_smoke_fail("client stream open failed");
    goto cleanup;
  }

  if (QUIC_FAILED(api->StreamStart(
        client_stream,
        QUIC_STREAM_START_FLAG_IMMEDIATE
      )))
  {
    ism_msquic_stream_smoke_fail("client stream start failed");
    goto cleanup;
  }

  if (!ism_msquic_stream_smoke_wait_for(
        &state,
        ISM_STREAM_SMOKE_WAIT_CLIENT_STREAM_STARTED
      ))
  {
    ism_msquic_stream_smoke_fail("client stream did not start");
    goto cleanup;
  }

  if (QUIC_FAILED(api->StreamSend(
        client_stream,
        &query_buffer,
        1U,
        QUIC_SEND_FLAG_FIN,
        &state
      )))
  {
    ism_msquic_stream_smoke_fail("client stream send failed");
    goto cleanup;
  }

  if (!ism_msquic_stream_smoke_wait_for(
        &state,
        ISM_STREAM_SMOKE_WAIT_SERVER_RESPONSE
      ))
  {
    ism_msquic_stream_smoke_fail("server response timed out");
    pthread_mutex_lock(&state.lock);
    ism_msquic_stream_smoke_report_state(&state);
    pthread_mutex_unlock(&state.lock);
    goto cleanup;
  }

  pthread_mutex_lock(&state.lock);
  bool ok =
    !state.failed &&
    state.server_stream_id == 0U &&
    state.server_send_complete &&
    state.client_response_finished &&
    state.client_response_len == (uint32_t)sizeof expected_response &&
    memcmp(
      state.client_response,
      expected_response,
      sizeof expected_response
    ) == 0;
  pthread_mutex_unlock(&state.lock);

  if (!ok)
  {
    ism_msquic_stream_smoke_fail(
      "client did not receive the expected DoQ response"
    );
    goto cleanup;
  }

  result = 0;

cleanup:
  if (client_stream != NULL && api != NULL)
  {
    (void)api->StreamShutdown(
      client_stream,
      QUIC_STREAM_SHUTDOWN_FLAG_ABORT |
        QUIC_STREAM_SHUTDOWN_FLAG_IMMEDIATE,
      0U
    );
  }

  if (client_stream != NULL && api != NULL)
  {
    api->StreamClose(client_stream);
  }

  if (client_connection != NULL && api != NULL)
  {
    api->ConnectionShutdown(
      client_connection,
      QUIC_CONNECTION_SHUTDOWN_FLAG_SILENT,
      0U
    );
  }

  if (client_connection != NULL && api != NULL)
  {
    api->ConnectionClose(client_connection);
  }

  if (listener != NULL && api != NULL)
  {
    if (listener_started)
    {
      api->ListenerStop(listener);
    }
    api->ListenerClose(listener);
  }

  if (client_configuration != NULL && api != NULL)
  {
    api->ConfigurationClose(client_configuration);
  }

  if (server_configuration != NULL && api != NULL)
  {
    api->ConfigurationClose(server_configuration);
  }

  if (client_registration != NULL && api != NULL)
  {
    api->RegistrationClose(client_registration);
  }

  if (server_registration != NULL && api != NULL)
  {
    api->RegistrationClose(server_registration);
  }

  if (api != NULL)
  {
    MsQuicClose(api);
  }

  pthread_mutex_destroy(&state.lock);
  return result;
}

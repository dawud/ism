#include "ism_shell.h"
#if defined(ISM_USE_PULSE_STREAM) && ISM_USE_PULSE_STREAM
#include "pulse_stream_adapter.h"
#endif
#if defined(ISM_USE_PULSE_TABLE) && ISM_USE_PULSE_TABLE
#include "pulse_table_adapter.h"
#endif

#include <stddef.h>
#include <string.h>

static void
ism_shell_reset_stream(ism_shell_stream *stream)
{
  stream->ctx.sc_id = 0U;
  stream->ctx.sc_phase = (DNS_QUIC_StreamMapping_stream_phase){
    .tag = DNS_QUIC_StreamMapping_ReadingLength
  };
  stream->ctx.sc_buf = stream->message_buffer;
  stream->active = false;
}

static bool
ism_shell_stream_is_active_ptr(
  const ism_shell_connection *conn,
  const DNS_QUIC_StreamMapping_stream_context *stream
)
{
  for (uint32_t i = 0U; i < conn->ctx.cc_num; i++)
  {
    if (conn->ctx.cc_active[i] == stream)
    {
      return true;
    }
  }

  return false;
}

static void
ism_shell_sync_stream_slots(ism_shell_connection *conn)
{
  for (uint32_t i = 0U; i < ISM_SHELL_MAX_STREAMS; i++)
  {
    ism_shell_stream *slot = &conn->streams[i];
    if (ism_shell_stream_is_active_ptr(conn, &slot->ctx))
    {
      slot->active = true;
    }
    else
    {
      ism_shell_reset_stream(slot);
    }
  }
}

void
ism_shell_connection_init(ism_shell_connection *conn)
{
  memset(conn, 0, sizeof *conn);
  conn->ctx.cc_active = conn->active;
  conn->ctx.cc_num = 0U;
  conn->ctx.cc_capacity = ISM_SHELL_MAX_STREAMS;

  for (uint32_t i = 0U; i < ISM_SHELL_MAX_STREAMS; i++)
  {
    ism_shell_reset_stream(&conn->streams[i]);
    conn->active[i] = &conn->streams[i].ctx;
  }
}

DNS_QUIC_StreamMapping_stream_context
*ism_shell_find_stream(ism_shell_connection *conn, uint64_t stream_id)
{
#if defined(ISM_USE_PULSE_TABLE) && ISM_USE_PULSE_TABLE
  return ism_pulse_table_find(conn, stream_id);
#else
  for (uint32_t i = 0U; i < conn->ctx.cc_num; i++)
  {
    DNS_QUIC_StreamMapping_stream_context *stream = conn->ctx.cc_active[i];
    if (stream != NULL && stream->sc_id == stream_id)
    {
      return stream;
    }
  }

  return NULL;
#endif
}

DNS_QUIC_StreamMapping_stream_context
*ism_shell_open_stream(ism_shell_connection *conn, uint64_t stream_id)
{
#if defined(ISM_USE_PULSE_TABLE) && ISM_USE_PULSE_TABLE
  return ism_pulse_table_open(conn, stream_id);
#else
  DNS_QUIC_StreamMapping_stream_context *existing =
    ism_shell_find_stream(conn, stream_id);
  if (existing != NULL)
  {
    return existing;
  }

  if (conn->ctx.cc_num >= conn->ctx.cc_capacity ||
      conn->ctx.cc_num >= ISM_SHELL_MAX_STREAMS)
  {
    return NULL;
  }

  for (uint32_t i = 0U; i < ISM_SHELL_MAX_STREAMS; i++)
  {
    ism_shell_stream *slot = &conn->streams[i];
    if (&slot->ctx == conn->ctx.cc_active[conn->ctx.cc_num] && !slot->active)
    {
      slot->ctx.sc_id = stream_id;
      slot->ctx.sc_phase = (DNS_QUIC_StreamMapping_stream_phase){
        .tag = DNS_QUIC_StreamMapping_ReadingLength
      };
      slot->ctx.sc_buf = slot->message_buffer;
      slot->active = true;
      conn->ctx.cc_num++;
      return &slot->ctx;
    }
  }

  return NULL;
#endif
}

uint8_t
ism_shell_on_authenticated_stream_fin(ism_shell_connection *conn, uint64_t stream_id)
{
  DNS_QUIC_StreamMapping_stream_context *stream =
    ism_shell_open_stream(conn, stream_id);
#if defined(ISM_USE_PULSE_STREAM) && ISM_USE_PULSE_STREAM
  return stream == NULL ? 3U : ism_pulse_ingress_fin(stream);
#else
  return stream == NULL ? 3U :
    DNS_ShellBoundary_dispatch_authenticated_stream_fin(stream);
#endif
}

uint8_t
ism_shell_on_authenticated_stream_data(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *data,
  uint32_t len
)
{
  DNS_QUIC_StreamMapping_stream_context *stream =
    ism_shell_open_stream(conn, stream_id);
  if (stream == NULL)
  {
    return DNS_ShellBoundary_shell_phase_code(
      (DNS_QUIC_StreamMapping_stream_phase){
        .tag = DNS_QUIC_StreamMapping_Done
      }
    );
  }

#if defined(ISM_USE_PULSE_STREAM) && ISM_USE_PULSE_STREAM
  return ism_pulse_ingress_data(stream, stream_id, data, len);
#else
  return
    DNS_ShellBoundary_dispatch_authenticated_stream_data(
      stream,
      stream_id,
      data,
      len
    );
#endif
}

uint8_t
ism_shell_dispatch_authenticated_stream_data(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *data,
  uint32_t len
)
{
  DNS_QUIC_StreamMapping_stream_context *stream =
    ism_shell_open_stream(conn, stream_id);
  if (stream == NULL)
  {
    return DNS_ShellBoundary_shell_phase_code(
      (DNS_QUIC_StreamMapping_stream_phase){
        .tag = DNS_QUIC_StreamMapping_Done
      }
    );
  }

#if defined(ISM_USE_PULSE_STREAM) && ISM_USE_PULSE_STREAM
  return ism_pulse_ingress_data(stream, stream_id, data, len);
#else
  return
    DNS_ShellBoundary_dispatch_authenticated_stream_data_via_scheduler(
      stream,
      stream_id,
      data,
      len
    );
#endif
}

uint32_t
ism_shell_prepare_response_send(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *response_buffer,
  uint32_t response_len,
  bool fin
)
{
  DNS_QUIC_StreamMapping_stream_context *stream =
    ism_shell_find_stream(conn, stream_id);
  if (stream == NULL)
  {
    return 0U;
  }

  return
    DNS_ShellResponseBoundary_prepare_response_send_for_stream(
      stream,
      response_buffer,
      response_len,
      fin ? 1U : 0U
    );
}

uint32_t
ism_shell_prepare_doq_response_send(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *response_buffer,
  uint32_t response_len,
  uint8_t *stream_buffer,
  uint32_t stream_capacity,
  bool fin
)
{
  DNS_QUIC_StreamMapping_stream_context *stream =
    ism_shell_find_stream(conn, stream_id);
  if (stream == NULL)
  {
    return 0U;
  }

  return
    DNS_ShellResponseBoundary_prepare_doq_response_send_for_stream(
      stream,
      response_buffer,
      response_len,
      stream_buffer,
      stream_capacity,
      fin ? 1U : 0U
    );
}

uint32_t
ism_shell_process_ready_stream(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *response_buffer,
  uint32_t response_capacity
)
{
  return
    DNS_ShellBoundary_process_ready_stream_for_response(
      &conn->ctx,
      response_buffer,
      response_capacity,
      stream_id
    );
}

uint32_t
ism_shell_process_ready_stream_empty_response(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *response_buffer,
  uint32_t response_capacity
)
{
  return
    DNS_ShellBoundary_process_ready_stream_for_empty_response(
      &conn->ctx,
      response_buffer,
      response_capacity,
      stream_id
    );
}

uint32_t
ism_shell_process_ready_stream_validated_minimal_response(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *response_buffer,
  uint32_t response_capacity
)
{
  return
    DNS_ShellBoundary_process_ready_stream_for_validated_minimal_response(
      &conn->ctx,
      response_buffer,
      response_capacity,
      stream_id
    );
}

uint32_t
ism_shell_dispatch_ready_stream(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *response_buffer,
  uint32_t response_capacity
)
{
  return
    DNS_ShellBoundary_dispatch_ready_stream_for_response_via_scheduler(
      &conn->ctx,
      response_buffer,
      response_capacity,
      stream_id
    );
}

uint32_t
ism_shell_dispatch_ready_stream_empty_response(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *response_buffer,
  uint32_t response_capacity
)
{
  return
    DNS_ShellBoundary_dispatch_ready_stream_for_empty_response_via_scheduler(
      &conn->ctx,
      response_buffer,
      response_capacity,
      stream_id
    );
}

uint32_t
ism_shell_dispatch_ready_stream_validated_minimal_response(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *response_buffer,
  uint32_t response_capacity
)
{
  return
    DNS_ShellBoundary_dispatch_ready_stream_for_validated_minimal_response_via_scheduler(
      &conn->ctx,
      response_buffer,
      response_capacity,
      stream_id
    );
}

uint8_t
ism_shell_complete_response_send(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *response_buffer,
  uint32_t response_len,
  bool dropped
)
{
#if defined(ISM_USE_PULSE_TABLE) && ISM_USE_PULSE_TABLE
  /* Existing completion consumes no response bytes and both outcomes close.
   * The runtime still owns send-buffer lifetime and callback serialization. */
  (void)response_buffer; (void)response_len; (void)dropped;
  uint8_t result = ism_pulse_table_close(conn, stream_id);
  if (result != 1U) return result;
#else
  uint8_t result =
    DNS_ShellResponseBoundary_complete_response_send_for_stream(
      &conn->ctx,
      response_buffer,
      response_len,
      stream_id,
      dropped ? 1U : 0U
    );
#endif

  for (uint32_t i = 0U; i < ISM_SHELL_MAX_STREAMS; i++)
  {
    if (conn->streams[i].active && conn->streams[i].ctx.sc_id == stream_id)
    {
      ism_shell_sync_stream_slots(conn);
      break;
    }
  }

  return result;
}

uint8_t
ism_shell_dispatch_response_send_finished(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *response_buffer,
  uint32_t response_len,
  bool dropped
)
{
#if defined(ISM_USE_PULSE_TABLE) && ISM_USE_PULSE_TABLE
  (void)response_buffer; (void)response_len; (void)dropped;
  uint8_t result = ism_pulse_table_close(conn, stream_id);
  if (result != 1U) return result;
#else
  uint8_t result =
    DNS_ShellBoundary_dispatch_response_send_finished_via_scheduler(
      &conn->ctx,
      response_buffer,
      response_len,
      stream_id,
      dropped ? 1U : 0U
    );
#endif

  for (uint32_t i = 0U; i < ISM_SHELL_MAX_STREAMS; i++)
  {
    if (conn->streams[i].active && conn->streams[i].ctx.sc_id == stream_id)
    {
      ism_shell_sync_stream_slots(conn);
      break;
    }
  }

  return result;
}

uint8_t
ism_shell_dispatch_stream_reset(
  ism_shell_connection *conn,
  uint64_t stream_id
)
{
#if defined(ISM_USE_PULSE_TABLE) && ISM_USE_PULSE_TABLE
  uint8_t result = ism_pulse_table_close(conn, stream_id);
#else
  uint8_t result =
    DNS_ShellBoundary_dispatch_stream_reset_via_scheduler(
      &conn->ctx,
      stream_id
    );
#endif

  if (result == 1U)
  {
    ism_shell_sync_stream_slots(conn);
  }

  return result;
}

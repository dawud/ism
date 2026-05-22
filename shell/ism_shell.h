#ifndef ISM_SHELL_H
#define ISM_SHELL_H

#include <stdbool.h>
#include <stdint.h>

#include "DNS_ShellBoundary.h"
#include "DNS_ShellResponseBoundary.h"

#define ISM_SHELL_MAX_STREAMS 4U
#define ISM_SHELL_STREAM_BUFFER_SIZE 65535U

typedef struct ism_shell_stream_s
{
  DNS_QUIC_StreamMapping_stream_context ctx;
  uint8_t message_buffer[ISM_SHELL_STREAM_BUFFER_SIZE];
  bool active;
}
ism_shell_stream;

typedef struct ism_shell_connection_s
{
  DNS_QUIC_Multiplexer_connection_context ctx;
  DNS_QUIC_StreamMapping_stream_context *active[ISM_SHELL_MAX_STREAMS];
  ism_shell_stream streams[ISM_SHELL_MAX_STREAMS];
}
ism_shell_connection;

void ism_shell_connection_init(ism_shell_connection *conn);

DNS_QUIC_StreamMapping_stream_context
*ism_shell_find_stream(ism_shell_connection *conn, uint64_t stream_id);

DNS_QUIC_StreamMapping_stream_context
*ism_shell_open_stream(ism_shell_connection *conn, uint64_t stream_id);

uint8_t
ism_shell_on_authenticated_stream_data(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *data,
  uint32_t len
);

uint8_t
ism_shell_dispatch_authenticated_stream_data(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *data,
  uint32_t len
);

uint32_t
ism_shell_prepare_response_send(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *response_buffer,
  uint32_t response_len,
  bool fin
);

uint32_t
ism_shell_process_ready_stream(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *response_buffer,
  uint32_t response_capacity
);

uint32_t
ism_shell_dispatch_ready_stream(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *response_buffer,
  uint32_t response_capacity
);

uint8_t
ism_shell_complete_response_send(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *response_buffer,
  uint32_t response_len,
  bool dropped
);

uint8_t
ism_shell_dispatch_response_send_finished(
  ism_shell_connection *conn,
  uint64_t stream_id,
  uint8_t *response_buffer,
  uint32_t response_len,
  bool dropped
);

#endif /* ISM_SHELL_H */

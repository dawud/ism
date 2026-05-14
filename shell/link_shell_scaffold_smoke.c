#include <stdbool.h>
#include <stdint.h>

#include "ism_shell.h"

bool ism_smoke_shell_scaffold(void)
{
  ism_shell_connection conn;
  uint8_t zero_length_doq_message[] = { 0U, 0U };
  uint8_t response_buffer[1] = { 0U };
  const uint64_t stream_id = 7U;

  ism_shell_connection_init(&conn);

  if (conn.ctx.cc_num != 0U ||
      conn.ctx.cc_capacity != ISM_SHELL_MAX_STREAMS)
  {
    return false;
  }

  uint8_t phase =
    ism_shell_on_authenticated_stream_data(
      &conn,
      stream_id,
      zero_length_doq_message,
      (uint32_t)sizeof zero_length_doq_message
    );
  if (phase != 2U || conn.ctx.cc_num != 1U)
  {
    return false;
  }

  uint32_t prepared =
    ism_shell_prepare_response_send(
      &conn,
      stream_id,
      response_buffer,
      0U,
      true
    );
  if (prepared != 0U)
  {
    return false;
  }

  uint8_t completed =
    ism_shell_complete_response_send(
      &conn,
      stream_id,
      response_buffer,
      prepared,
      false
    );

  return completed == 1U && conn.ctx.cc_num == 0U;
}

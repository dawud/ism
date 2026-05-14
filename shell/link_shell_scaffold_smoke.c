#include <stdbool.h>
#include <stdint.h>

#include "ism_shell.h"

bool ism_smoke_shell_scaffold(void)
{
  ism_shell_connection conn;
  uint8_t zero_length_doq_message[] = { 0U, 0U };
  uint8_t response_buffer[1] = { 0U };
  const uint64_t first_stream_id = 7U;
  const uint64_t second_stream_id = 9U;
  const uint64_t third_stream_id = 11U;

  ism_shell_connection_init(&conn);

  if (conn.ctx.cc_num != 0U ||
      conn.ctx.cc_capacity != ISM_SHELL_MAX_STREAMS)
  {
    return false;
  }

  uint8_t phase =
    ism_shell_on_authenticated_stream_data(
      &conn,
      first_stream_id,
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
      first_stream_id,
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
      first_stream_id,
      response_buffer,
      prepared,
      false
    );

  if (completed != 1U || conn.ctx.cc_num != 0U)
  {
    return false;
  }

  if
  (
    ism_shell_on_authenticated_stream_data(
      &conn,
      first_stream_id,
      zero_length_doq_message,
      (uint32_t)sizeof zero_length_doq_message
    ) != 2U ||
    ism_shell_on_authenticated_stream_data(
      &conn,
      second_stream_id,
      zero_length_doq_message,
      (uint32_t)sizeof zero_length_doq_message
    ) != 2U ||
    conn.ctx.cc_num != 2U
  )
  {
    return false;
  }

  completed =
    ism_shell_complete_response_send(
      &conn,
      first_stream_id,
      response_buffer,
      0U,
      false
    );
  if (completed != 1U ||
      conn.ctx.cc_num != 1U ||
      ism_shell_find_stream(&conn, first_stream_id) != 0 ||
      ism_shell_find_stream(&conn, second_stream_id) == 0)
  {
    return false;
  }

  if (ism_shell_open_stream(&conn, third_stream_id) == 0 ||
      conn.ctx.cc_num != 2U ||
      ism_shell_find_stream(&conn, second_stream_id) == 0 ||
      ism_shell_find_stream(&conn, third_stream_id) == 0)
  {
    return false;
  }

  return true;
}

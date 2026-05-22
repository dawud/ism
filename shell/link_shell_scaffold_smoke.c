#include <stdbool.h>
#include <stdint.h>

#include "ism_shell.h"

bool ism_smoke_shell_scaffold(void)
{
  ism_shell_connection conn;
  ism_shell_connection worker_conn;
  uint8_t zero_length_doq_message[] = { 0U, 0U };
  uint8_t response_buffer[1] = { 0U };
  uint8_t exact_a_query[] = {
    0x00U, 0x21U,
    0x12U, 0x34U,
    0x01U, 0x00U,
    0x00U, 0x01U,
    0x00U, 0x00U,
    0x00U, 0x00U,
    0x00U, 0x00U,
    0x03U, 0x63U, 0x6fU, 0x6dU,
    0x07U, 0x65U, 0x78U, 0x61U, 0x6dU, 0x70U, 0x6cU, 0x65U,
    0x03U, 0x77U, 0x77U, 0x77U,
    0x00U,
    0x00U, 0x01U,
    0x00U, 0x01U
  };
  uint8_t worker_response[128] = { 0U };
  const uint64_t first_stream_id = 7U;
  const uint64_t second_stream_id = 9U;
  const uint64_t third_stream_id = 11U;
  const uint64_t worker_stream_id = 13U;

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

  ism_shell_connection_init(&worker_conn);

  if (ism_shell_on_authenticated_stream_data(
        &worker_conn,
        worker_stream_id,
        exact_a_query,
        (uint32_t)sizeof exact_a_query
      ) != 2U)
  {
    return false;
  }

  uint32_t worker_response_len =
    ism_shell_process_ready_stream(
      &worker_conn,
      worker_stream_id,
      worker_response,
      (uint32_t)sizeof worker_response
    );

  if (worker_response_len != 33U ||
      worker_response[0] != 0x12U ||
      worker_response[1] != 0x34U ||
      worker_response[2] != 0x81U ||
      worker_response[3] != 0x03U ||
      worker_response[4] != 0x00U ||
      worker_response[5] != 0x01U ||
      worker_response[6] != 0x00U ||
      worker_response[7] != 0x00U ||
      worker_response[31] != 0x00U ||
      worker_response[32] != 0x01U)
  {
    return false;
  }

  return true;
}

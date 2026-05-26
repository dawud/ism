#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "ism_shell.h"

bool ism_smoke_shell_scaffold(void)
{
  ism_shell_connection conn;
  ism_shell_connection worker_conn;
  ism_shell_connection dispatcher_conn;
  ism_shell_connection empty_worker_conn;
  ism_shell_connection empty_dispatcher_conn;
  ism_shell_connection validated_worker_conn;
  ism_shell_connection validated_dispatcher_conn;
  ism_shell_connection invalid_validated_conn;
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
  uint8_t invalid_header_query[] = {
    0x00U, 0x0cU,
    0x56U, 0x78U,
    0x01U, 0x00U,
    0x00U, 0x00U,
    0x00U, 0x00U,
    0x00U, 0x00U,
    0x00U, 0x00U
  };
  uint8_t expected_validated_response[] = {
    0x12U, 0x34U,
    0x81U, 0x00U,
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
  uint8_t dispatcher_response[128] = { 0U };
  uint8_t empty_worker_response[128] = { 0U };
  uint8_t empty_dispatcher_response[128] = { 0U };
  uint8_t validated_worker_response[128] = { 0U };
  uint8_t validated_dispatcher_response[128] = { 0U };
  uint8_t invalid_validated_response[128] = { 0U };
  const uint64_t first_stream_id = 7U;
  const uint64_t second_stream_id = 9U;
  const uint64_t third_stream_id = 11U;
  const uint64_t worker_stream_id = 13U;
  const uint64_t dispatcher_stream_id = 15U;
  const uint64_t empty_worker_stream_id = 17U;
  const uint64_t empty_dispatcher_stream_id = 19U;
  const uint64_t validated_worker_stream_id = 21U;
  const uint64_t validated_dispatcher_stream_id = 23U;
  const uint64_t invalid_validated_stream_id = 25U;

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

  if (worker_response_len != 12U ||
      worker_response[0] != 0x12U ||
      worker_response[1] != 0x34U ||
      worker_response[2] != 0x81U ||
      worker_response[3] != 0x03U ||
      worker_response[4] != 0x00U ||
      worker_response[5] != 0x00U ||
      worker_response[6] != 0x00U ||
      worker_response[7] != 0x00U ||
      worker_response[8] != 0x00U ||
      worker_response[9] != 0x00U ||
      worker_response[10] != 0x00U ||
      worker_response[11] != 0x00U)
  {
    return false;
  }

  ism_shell_connection_init(&dispatcher_conn);

  if (ism_shell_dispatch_authenticated_stream_data(
        &dispatcher_conn,
        dispatcher_stream_id,
        exact_a_query,
        (uint32_t)sizeof exact_a_query
      ) != 2U)
  {
    return false;
  }

  uint32_t dispatcher_response_len =
    ism_shell_dispatch_ready_stream(
      &dispatcher_conn,
      dispatcher_stream_id,
      dispatcher_response,
      (uint32_t)sizeof dispatcher_response
    );

  if (dispatcher_response_len != 12U ||
      dispatcher_response[0] != 0x12U ||
      dispatcher_response[1] != 0x34U ||
      dispatcher_response[2] != 0x81U ||
      dispatcher_response[3] != 0x03U ||
      dispatcher_response[4] != 0x00U ||
      dispatcher_response[5] != 0x00U ||
      dispatcher_response[6] != 0x00U ||
      dispatcher_response[7] != 0x00U ||
      dispatcher_response[8] != 0x00U ||
      dispatcher_response[9] != 0x00U ||
      dispatcher_response[10] != 0x00U ||
      dispatcher_response[11] != 0x00U)
  {
    return false;
  }

  if (ism_shell_dispatch_response_send_finished(
        &dispatcher_conn,
        dispatcher_stream_id,
        dispatcher_response,
        dispatcher_response_len,
        false
      ) != 1U ||
      dispatcher_conn.ctx.cc_num != 0U)
  {
    return false;
  }

  ism_shell_connection_init(&empty_worker_conn);

  if (ism_shell_on_authenticated_stream_data(
        &empty_worker_conn,
        empty_worker_stream_id,
        exact_a_query,
        (uint32_t)sizeof exact_a_query
      ) != 2U)
  {
    return false;
  }

  uint32_t empty_worker_response_len =
    ism_shell_process_ready_stream_empty_response(
      &empty_worker_conn,
      empty_worker_stream_id,
      empty_worker_response,
      (uint32_t)sizeof empty_worker_response
    );

  if (empty_worker_response_len != 12U ||
      empty_worker_response[0] != 0x12U ||
      empty_worker_response[1] != 0x34U ||
      empty_worker_response[2] != 0x81U ||
      empty_worker_response[3] != 0x00U ||
      empty_worker_response[4] != 0x00U ||
      empty_worker_response[5] != 0x00U ||
      empty_worker_response[6] != 0x00U ||
      empty_worker_response[7] != 0x00U ||
      empty_worker_response[8] != 0x00U ||
      empty_worker_response[9] != 0x00U ||
      empty_worker_response[10] != 0x00U ||
      empty_worker_response[11] != 0x00U)
  {
    return false;
  }

  ism_shell_connection_init(&empty_dispatcher_conn);

  if (ism_shell_dispatch_authenticated_stream_data(
        &empty_dispatcher_conn,
        empty_dispatcher_stream_id,
        exact_a_query,
        (uint32_t)sizeof exact_a_query
      ) != 2U)
  {
    return false;
  }

  uint32_t empty_dispatcher_response_len =
    ism_shell_dispatch_ready_stream_empty_response(
      &empty_dispatcher_conn,
      empty_dispatcher_stream_id,
      empty_dispatcher_response,
      (uint32_t)sizeof empty_dispatcher_response
    );

  if (empty_dispatcher_response_len != 12U ||
      empty_dispatcher_response[0] != 0x12U ||
      empty_dispatcher_response[1] != 0x34U ||
      empty_dispatcher_response[2] != 0x81U ||
      empty_dispatcher_response[3] != 0x00U ||
      empty_dispatcher_response[4] != 0x00U ||
      empty_dispatcher_response[5] != 0x00U ||
      empty_dispatcher_response[6] != 0x00U ||
      empty_dispatcher_response[7] != 0x00U ||
      empty_dispatcher_response[8] != 0x00U ||
      empty_dispatcher_response[9] != 0x00U ||
      empty_dispatcher_response[10] != 0x00U ||
      empty_dispatcher_response[11] != 0x00U)
  {
    return false;
  }

  if (ism_shell_dispatch_response_send_finished(
        &empty_dispatcher_conn,
        empty_dispatcher_stream_id,
        empty_dispatcher_response,
        empty_dispatcher_response_len,
        false
      ) != 1U ||
      empty_dispatcher_conn.ctx.cc_num != 0U)
  {
    return false;
  }

  ism_shell_connection_init(&validated_worker_conn);

  if (ism_shell_on_authenticated_stream_data(
        &validated_worker_conn,
        validated_worker_stream_id,
        exact_a_query,
        (uint32_t)sizeof exact_a_query
      ) != 2U)
  {
    return false;
  }

  uint32_t validated_worker_response_len =
    ism_shell_process_ready_stream_validated_minimal_response(
      &validated_worker_conn,
      validated_worker_stream_id,
      validated_worker_response,
      (uint32_t)sizeof validated_worker_response
    );

  if (validated_worker_response_len !=
        (uint32_t)sizeof expected_validated_response ||
      memcmp(
        validated_worker_response,
        expected_validated_response,
        sizeof expected_validated_response
      ) != 0)
  {
    return false;
  }

  ism_shell_connection_init(&validated_dispatcher_conn);

  if (ism_shell_dispatch_authenticated_stream_data(
        &validated_dispatcher_conn,
        validated_dispatcher_stream_id,
        exact_a_query,
        (uint32_t)sizeof exact_a_query
      ) != 2U)
  {
    return false;
  }

  uint32_t validated_dispatcher_response_len =
    ism_shell_dispatch_ready_stream_validated_minimal_response(
      &validated_dispatcher_conn,
      validated_dispatcher_stream_id,
      validated_dispatcher_response,
      (uint32_t)sizeof validated_dispatcher_response
    );

  if (validated_dispatcher_response_len !=
        (uint32_t)sizeof expected_validated_response ||
      memcmp(
        validated_dispatcher_response,
        expected_validated_response,
        sizeof expected_validated_response
      ) != 0)
  {
    return false;
  }

  if (ism_shell_dispatch_response_send_finished(
        &validated_dispatcher_conn,
        validated_dispatcher_stream_id,
        validated_dispatcher_response,
        validated_dispatcher_response_len,
        false
      ) != 1U ||
      validated_dispatcher_conn.ctx.cc_num != 0U)
  {
    return false;
  }

  ism_shell_connection_init(&invalid_validated_conn);

  if (ism_shell_dispatch_authenticated_stream_data(
        &invalid_validated_conn,
        invalid_validated_stream_id,
        invalid_header_query,
        (uint32_t)sizeof invalid_header_query
      ) != 2U)
  {
    return false;
  }

  uint32_t invalid_validated_response_len =
    ism_shell_dispatch_ready_stream_validated_minimal_response(
      &invalid_validated_conn,
      invalid_validated_stream_id,
      invalid_validated_response,
      (uint32_t)sizeof invalid_validated_response
    );

  if (invalid_validated_response_len != 12U ||
      invalid_validated_response[0] != 0x56U ||
      invalid_validated_response[1] != 0x78U ||
      invalid_validated_response[2] != 0x81U ||
      invalid_validated_response[3] != 0x03U ||
      invalid_validated_response[4] != 0x00U ||
      invalid_validated_response[5] != 0x00U ||
      invalid_validated_response[6] != 0x00U ||
      invalid_validated_response[7] != 0x00U ||
      invalid_validated_response[8] != 0x00U ||
      invalid_validated_response[9] != 0x00U ||
      invalid_validated_response[10] != 0x00U ||
      invalid_validated_response[11] != 0x00U)
  {
    return false;
  }

  return true;
}

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "ism_event_queue.h"

typedef struct queue_fake_send_s
{
  bool called;
  uint64_t stream_id;
  uint32_t len;
  bool fin;
}
queue_fake_send;

static bool
queue_fake_send_fn(
  void *ctx,
  uint64_t stream_id,
  uint8_t *data,
  uint32_t len,
  bool fin
)
{
  queue_fake_send *capture = (queue_fake_send *)ctx;
  if (capture == 0 || data == 0)
  {
    return false;
  }

  capture->called = true;
  capture->stream_id = stream_id;
  capture->len = len;
  capture->fin = fin;
  return true;
}

bool ism_smoke_event_queue(void)
{
  ism_shell_event storage[4];
  ism_shell_event_queue queue;
  ism_shell_event event;
  ism_msquic_adapter adapter;
  uint8_t response[128] = { 0U };
  uint8_t send_buffer[128] = { 0U };
  queue_fake_send capture = { 0 };
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
  uint8_t expected_validated_stream_response[] = {
    0x00U, 0x21U,
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
  const uint64_t stream_id = 31U;

  ism_shell_event_queue_init(&queue, storage, 2U);

  if (!ism_shell_event_queue_enqueue_authenticated_stream_bytes(
        &queue,
        1U,
        exact_a_query,
        (uint32_t)sizeof exact_a_query
      ) ||
      !ism_shell_event_queue_enqueue_ready_response(&queue, 2U) ||
      ism_shell_event_queue_enqueue_send_complete(&queue, 3U, 4U, false) ||
      ism_shell_event_queue_len(&queue) != 2U)
  {
    return false;
  }

  if (!ism_shell_event_queue_dequeue(&queue, &event) ||
      event.kind != ISM_SHELL_EVENT_AUTHENTICATED_STREAM_BYTES ||
      event.stream_id != 1U ||
      event.data != exact_a_query ||
      event.len != (uint32_t)sizeof exact_a_query)
  {
    return false;
  }

  if (!ism_shell_event_queue_dequeue(&queue, &event) ||
      event.kind != ISM_SHELL_EVENT_READY_RESPONSE ||
      event.stream_id != 2U ||
      ism_shell_event_queue_dequeue(&queue, &event))
  {
    return false;
  }

  ism_shell_event_queue_init(&queue, storage, 1U);
  ism_msquic_adapter_init(
    &adapter,
    response,
    (uint32_t)sizeof response,
    send_buffer,
    (uint32_t)sizeof send_buffer,
    queue_fake_send_fn,
    &capture
  );

  if (!ism_shell_event_queue_enqueue_authenticated_stream_bytes(
        &queue,
        stream_id,
        exact_a_query,
        (uint32_t)sizeof exact_a_query
      ) ||
      !ism_shell_event_queue_dispatch_one(&queue, &adapter) ||
      !capture.called ||
      capture.stream_id != stream_id ||
      capture.len != (uint32_t)sizeof expected_validated_stream_response ||
      !capture.fin ||
      ism_shell_event_queue_len(&queue) != 0U ||
      memcmp(
        send_buffer,
        expected_validated_stream_response,
        sizeof expected_validated_stream_response
      ) != 0)
  {
    return false;
  }

  if (!ism_shell_event_queue_enqueue_send_complete(
        &queue,
        stream_id,
        capture.len,
        false
      ) ||
      !ism_shell_event_queue_dispatch_one(&queue, &adapter) ||
      adapter.connection.ctx.cc_num != 0U)
  {
    return false;
  }

  if (!ism_shell_event_queue_enqueue_authenticated_stream_bytes(
        &queue,
        stream_id,
        exact_a_query,
        1U
      ) ||
      !ism_shell_event_queue_dispatch_one(&queue, &adapter) ||
      adapter.connection.ctx.cc_num != 1U ||
      !ism_shell_event_queue_enqueue_stream_reset(
        &queue,
        stream_id
      ) ||
      !ism_shell_event_queue_dispatch_one(&queue, &adapter) ||
      adapter.connection.ctx.cc_num != 0U)
  {
    return false;
  }

  return true;
}

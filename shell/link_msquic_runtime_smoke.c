#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "msquic_runtime.h"

typedef struct runtime_send_capture_s
{
  bool called;
  uint64_t stream_id;
  uint32_t len;
  bool fin;
}
runtime_send_capture;

static bool
runtime_fake_send(
  void *ctx,
  uint64_t stream_id,
  uint8_t *data,
  uint32_t len,
  bool fin
)
{
  runtime_send_capture *capture = (runtime_send_capture *)ctx;
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

bool ism_smoke_msquic_runtime(void)
{
  ism_msquic_adapter adapter;
  ism_shell_event events[1];
  ism_shell_event_queue queue;
  ism_msquic_runtime_stream runtime;
  runtime_send_capture capture = { 0 };
  uint8_t response[128] = { 0U };
  uint8_t send_buffer[128] = { 0U };
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
  ism_msquic_runtime_buffer buffers[] = {
    {
      .data = exact_a_query,
      .len = (uint32_t)sizeof exact_a_query
    }
  };
  const uint64_t stream_id = 31U;

  ism_msquic_adapter_init(
    &adapter,
    response,
    (uint32_t)sizeof response,
    send_buffer,
    (uint32_t)sizeof send_buffer,
    runtime_fake_send,
    &capture
  );
  ism_shell_event_queue_init(&queue, events, 1U);
  ism_msquic_runtime_stream_init(&runtime, &adapter, &queue, stream_id);

  if (!ism_msquic_runtime_on_receive(
        &runtime,
        buffers,
        (uint32_t)(sizeof buffers / sizeof buffers[0])
      ) ||
      !capture.called ||
      capture.stream_id != stream_id ||
      capture.len != (uint32_t)sizeof expected_validated_stream_response ||
      !capture.fin ||
      memcmp(
        send_buffer,
        expected_validated_stream_response,
        sizeof expected_validated_stream_response
      ) != 0 ||
      ism_shell_event_queue_len(&queue) != 0U)
  {
    return false;
  }

  if (!ism_msquic_runtime_on_send_complete(
        &runtime,
        capture.len,
        false
      ) ||
      adapter.connection.ctx.cc_num != 0U ||
      ism_shell_event_queue_len(&queue) != 0U)
  {
    return false;
  }

  return true;
}

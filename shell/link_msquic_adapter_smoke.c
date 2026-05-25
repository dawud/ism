#include <stdbool.h>
#include <stdint.h>

#include "msquic_adapter.h"

typedef struct fake_msquic_send_s
{
  bool called;
  uint64_t stream_id;
  uint32_t len;
  bool fin;
  uint8_t first;
  uint8_t second;
  uint8_t rcode_low;
}
fake_msquic_send;

static bool
fake_send(
  void *ctx,
  uint64_t stream_id,
  uint8_t *data,
  uint32_t len,
  bool fin
)
{
  fake_msquic_send *capture = (fake_msquic_send *)ctx;
  if (capture == 0)
  {
    return false;
  }

  capture->called = true;
  capture->stream_id = stream_id;
  capture->len = len;
  capture->fin = fin;

  if (len > 0U)
  {
    capture->first = data[0];
  }
  if (len > 1U)
  {
    capture->second = data[1];
  }
  if (len > 3U)
  {
    capture->rcode_low = data[3];
  }

  return true;
}

bool ism_smoke_msquic_adapter(void)
{
  ism_msquic_adapter adapter;
  ism_msquic_adapter capped_adapter;
  uint8_t response[128] = { 0U };
  uint8_t capped_response[1] = { 0U };
  fake_msquic_send capture = { 0 };
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
  const uint64_t stream_id = 17U;

  ism_msquic_adapter_init(
    &adapter,
    response,
    (uint32_t)sizeof response,
    fake_send,
    &capture
  );

  uint8_t phase =
    ism_msquic_adapter_on_authenticated_stream_bytes(
      &adapter,
      stream_id,
      exact_a_query,
      (uint32_t)sizeof exact_a_query
    );

  if (phase != 2U ||
      !capture.called ||
      capture.stream_id != stream_id ||
      capture.len != 12U ||
      !capture.fin ||
      capture.first != 0x12U ||
      capture.second != 0x34U ||
      capture.rcode_low != 0x03U)
  {
    return false;
  }

  if (!ism_msquic_adapter_on_send_complete(
        &adapter,
        stream_id,
        capture.len,
        false
      ) ||
      adapter.connection.ctx.cc_num != 0U)
  {
    return false;
  }

  ism_msquic_adapter_init(
    &capped_adapter,
    capped_response,
    0U,
    fake_send,
    &capture
  );

  if (ism_msquic_adapter_prepare_ready_response(
        &capped_adapter,
        stream_id
      ) != 0U ||
      ism_msquic_adapter_on_send_complete(
        &capped_adapter,
        stream_id,
        0U,
        false
      ))
  {
    return false;
  }

  return true;
}

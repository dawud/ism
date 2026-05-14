#include <stdbool.h>
#include <stdint.h>

#include "DNS_ShellResponseBoundary.h"

bool ism_smoke_shell_response_boundary(void)
{
  uint32_t
  (*prepare)(
    DNS_QUIC_StreamMapping_stream_context *ctx_ptr,
    uint8_t *response_buffer,
    uint32_t response_len,
    uint8_t fin_code
  ) = DNS_ShellResponseBoundary_prepare_response_send_for_stream;
  uint8_t
  (*complete)(
    DNS_QUIC_Multiplexer_connection_context *conn,
    uint8_t *response_buffer,
    uint32_t response_len,
    uint64_t stream_id,
    uint8_t outcome_code
  ) = DNS_ShellResponseBoundary_complete_response_send_for_stream;

  return prepare != 0 && complete != 0;
}

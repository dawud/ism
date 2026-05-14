#include <stdbool.h>
#include <stdint.h>

#include "DNS_ShellBoundary.h"

bool ism_smoke_shell_boundary(void)
{
  DNS_QUIC_StreamMapping_stream_phase done = {
    .tag = DNS_QUIC_StreamMapping_Done
  };
  uint8_t
  (*dispatch)(
    DNS_QUIC_StreamMapping_stream_context *ctx_ptr,
    uint64_t stream_id,
    uint8_t *data,
    uint32_t len
  ) = DNS_ShellBoundary_dispatch_authenticated_stream_data;

  return dispatch != 0 && DNS_ShellBoundary_shell_phase_code(done) == 3;
}

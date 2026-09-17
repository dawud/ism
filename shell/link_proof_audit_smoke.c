#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "ism_shell.h"
#include "DNSProtocolWrapper.h"

bool ism_smoke_proof_audit(void)
{
  /* Root IN A query: seventeen DNS bytes, zero DoQ ID. */
  uint8_t query[] = {0,17, 0,0,1,0,0,1,0,0,0,0,0,0, 0,0,1,0,1};
  uint8_t response[64];
  static ism_shell_connection conn;

  /* Include every split, particularly between the two prefix bytes and just
     after the declared body. The same bytes must have the same outcome. */
  for (uint32_t split = 0; split <= sizeof query; ++split)
  {
    ism_shell_connection_init(&conn);
    (void)ism_shell_dispatch_authenticated_stream_data(&conn, 4, query, split);
    if (ism_shell_dispatch_authenticated_stream_data(
          &conn, 4, query + split, sizeof query - split) != 4U ||
        ism_shell_process_ready_stream_validated_minimal_response(
          &conn, 4, response, sizeof response) != 0U ||
        memcmp(ism_shell_find_stream(&conn, 4)->sc_buf, query + 2, sizeof query - 2) != 0 ||
        ism_shell_on_authenticated_stream_fin(&conn, 4) != 2U ||
        ism_shell_process_ready_stream_validated_minimal_response(
          &conn, 4, response, sizeof response) != 17U ||
        response[0] != 0 || response[1] != 0 || response[3] != 0)
    {
      return false;
    }
  }

  uint8_t excess[sizeof query + 1];
  memcpy(excess, query, sizeof query);
  excess[sizeof query] = 0xff;
  for (uint32_t split = 0; split <= sizeof excess; ++split)
  {
    ism_shell_connection_init(&conn);
    (void)ism_shell_dispatch_authenticated_stream_data(&conn, 4, excess, split);
    if (ism_shell_dispatch_authenticated_stream_data(
          &conn, 4, excess + split, sizeof excess - split) != 3U ||
        ism_shell_on_authenticated_stream_fin(&conn, 4) != 3U)
    {
      return false;
    }
  }

  for (uint32_t cut = 0; cut < sizeof query; ++cut)
  {
    ism_shell_connection_init(&conn);
    (void)ism_shell_dispatch_authenticated_stream_data(&conn, 4, query, cut);
    if (ism_shell_on_authenticated_stream_fin(&conn, 4) != 3U)
    {
      return false;
    }
  }
  for (uint8_t size = 0; size < 12; ++size)
  {
    uint8_t prefix[] = {0, size};
    ism_shell_connection_init(&conn);
    if (ism_shell_dispatch_authenticated_stream_data(&conn, 4, prefix, 2) != 3U)
    {
      return false;
    }
  }

  query[2] = 0x12;
  query[3] = 0x34;
  ism_shell_connection_init(&conn);
  if (ism_shell_dispatch_authenticated_stream_data(&conn, 4, query, sizeof query) != 4U ||
      ism_shell_on_authenticated_stream_fin(&conn, 4) != 3U ||
      ism_shell_process_ready_stream_validated_minimal_response(&conn, 4, response, sizeof response) != 0U)
  {
    return false;
  }

  /* The old close left [B,B]; reopening then destroyed B in the F* allocator. */
  ism_shell_connection_init(&conn);
  DNS_QUIC_StreamMapping_stream_context *a = ism_shell_open_stream(&conn, 0);
  DNS_QUIC_StreamMapping_stream_context *b = ism_shell_open_stream(&conn, 4);
  if (a == NULL || b == NULL || a == b ||
      ism_shell_dispatch_stream_reset(&conn, 0) != 1U ||
      conn.ctx.cc_num != 1 || conn.active[0] != b || conn.active[1] != a ||
      ism_shell_open_stream(&conn, 8) != a || b->sc_id != 4 ||
      ism_shell_open_stream(&conn, 8) != a || conn.ctx.cc_num != 2)
  {
    return false;
  }
  for (uint32_t i = 0; i < ISM_SHELL_MAX_STREAMS; ++i)
  {
    for (uint32_t j = i + 1; j < ISM_SHELL_MAX_STREAMS; ++j)
    {
      if (conn.active[i] == conn.active[j]) return false;
    }
  }

  uint8_t pointer_packet[] = {
    0,0,0x81,0x80,0,1,0,1,0,0,0,0, 0,0,1,0,1,
    0xc0,0,0,1,0,1,0,0,0,1,0,4,127,0,0,1
  };
  if (DnsprotocolCheckDnsUncompressedQuestionCompressedAnswerNamePacket(
        1,4,192,0,pointer_packet,sizeof pointer_packet))
  {
    return false;
  }
  pointer_packet[18] = 12;
  return DnsprotocolCheckDnsUncompressedQuestionCompressedAnswerNamePacket(
    1,4,192,12,pointer_packet,sizeof pointer_packet);
}

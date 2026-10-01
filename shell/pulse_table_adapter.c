#include "pulse_table_adapter.h"
#include "pulse_stream_adapter.h"
#include "ism_pulse_table.h"

_Static_assert(ISM_SHELL_MAX_STREAMS == ISM_PULSE_TABLE_SLOTS, "table capacity mismatch");
_Static_assert(ISM_SHELL_STREAM_BUFFER_SIZE == ISM_PULSE_MESSAGE_CAPACITY, "buffer capacity mismatch");

static bool snapshot(ism_shell_connection *conn, ism_pulse_table *wire)
{
  if (conn == NULL || ism_pulse_table_abi_version() != ISM_PULSE_TABLE_ABI_VERSION ||
      conn->ctx.cc_active != conn->active || conn->ctx.cc_num > conn->ctx.cc_capacity ||
      conn->ctx.cc_capacity > ISM_SHELL_MAX_STREAMS) return false;
  *wire = (ism_pulse_table){.count = conn->ctx.cc_num, .capacity = conn->ctx.cc_capacity};
  bool active[ISM_SHELL_MAX_STREAMS] = {false};
  bool seen[ISM_SHELL_MAX_STREAMS] = {false};
  for (uint32_t i = 0; i < ISM_SHELL_MAX_STREAMS; ++i) {
    uint32_t physical = 0;
    while (physical < ISM_SHELL_MAX_STREAMS &&
           conn->active[i] != &conn->streams[physical].ctx) ++physical;
    if (physical == ISM_SHELL_MAX_STREAMS || seen[physical]) return false;
    wire->order[i] = physical;
    seen[physical] = true;
    active[physical] = i < wire->count;
  }
  for (uint32_t i = 0; i < ISM_SHELL_MAX_STREAMS; ++i) {
    ism_shell_stream *s = &conn->streams[i];
    if (s->ctx.sc_buf != s->message_buffer || s->active != active[i]) return false;
    wire->slots[i] = (ism_pulse_table_slot){.id = s->ctx.sc_id,
      .phase = ism_pulse_phase_to_wire(s->ctx.sc_phase),
      .message = s->message_buffer, .message_capacity = sizeof s->message_buffer};
  }
  return true;
}

DNS_QUIC_StreamMapping_stream_context *ism_pulse_table_find(ism_shell_connection *conn, uint64_t id)
{
  ism_pulse_table wire;
  if (!snapshot(conn, &wire)) return NULL;
  uint32_t index = ism_pulse_table_apply(&wire, ISM_PULSE_TABLE_FIND, id);
  return index < wire.count ? &conn->streams[wire.order[index]].ctx : NULL;
}

DNS_QUIC_StreamMapping_stream_context *ism_pulse_table_open(ism_shell_connection *conn, uint64_t id)
{
  ism_pulse_table wire;
  if (!snapshot(conn, &wire)) return NULL;
  uint32_t index = ism_pulse_table_apply(&wire, ISM_PULSE_TABLE_FIND, id);
  if (index == ISM_PULSE_TABLE_INVALID) return NULL;
  /* Shell open is idempotent, unlike the underlying allocate primitive. */
  if (index < wire.count) return &conn->streams[wire.order[index]].ctx;
  index = ism_pulse_table_apply(&wire, ISM_PULSE_TABLE_ALLOCATE, id);
  if (index >= wire.capacity) return NULL;
  uint32_t physical = wire.order[index];
  ism_shell_stream *slot = &conn->streams[physical];
  slot->ctx.sc_id = wire.slots[physical].id;
  slot->ctx.sc_phase = ism_pulse_phase_from_wire(wire.slots[physical].phase);
  slot->active = true;
  conn->ctx.cc_num = wire.count;
  return &slot->ctx;
}

uint8_t ism_pulse_table_close(ism_shell_connection *conn, uint64_t id)
{
  ism_pulse_table wire;
  if (!snapshot(conn, &wire)) return 0U;
  uint32_t result = ism_pulse_table_apply(&wire, ISM_PULSE_TABLE_CLOSE, id);
  if (result == ISM_PULSE_TABLE_INVALID) return 0U;
  if (result == 1U) {
    for (uint32_t i = 0; i < ISM_SHELL_MAX_STREAMS; ++i)
      conn->active[i] = &conn->streams[wire.order[i]].ctx;
    conn->ctx.cc_num = wire.count;
  }
  return 1U; /* Legacy reset/completion also return 1 on a missing stream. */
}

#include "ism_pulse_table.h"
#include "DNS_Migration_PulseMultiplexer.h"
#include "pulse_phase_decode.h"

static bool range_ok(const void *p, size_t n)
{
  return p != NULL && n <= UINTPTR_MAX - (uintptr_t)p;
}

static bool disjoint(const void *a, size_t an, const void *b, size_t bn)
{
  uintptr_t ap = (uintptr_t)a, bp = (uintptr_t)b;
  return range_ok(a, an) && range_ok(b, bn) && (ap + an <= bp || bp + bn <= ap);
}

uint32_t ism_pulse_table_abi_version(void) { return ISM_PULSE_TABLE_ABI_VERSION; }

uint32_t ism_pulse_table_apply(ism_pulse_table *wire, uint32_t operation, uint64_t id)
{
  if (!range_ok(wire, sizeof *wire) || (uintptr_t)wire % _Alignof(ism_pulse_table) != 0 ||
      operation > ISM_PULSE_TABLE_CLOSE) return ISM_PULSE_TABLE_INVALID;
  if (wire->count > wire->capacity || wire->capacity > ISM_PULSE_TABLE_SLOTS)
    return ISM_PULSE_TABLE_INVALID;

  DNS_Migration_PulseStream_stream_context contexts[ISM_PULSE_TABLE_SLOTS];
  DNS_Migration_PulseStream_stream_context *order[ISM_PULSE_TABLE_SLOTS];
  for (uint32_t i = 0; i < ISM_PULSE_TABLE_SLOTS; ++i) {
    const ism_pulse_table_slot *slot = &wire->slots[i];
    if (wire->order[i] >= ISM_PULSE_TABLE_SLOTS ||
        slot->message_capacity < ISM_PULSE_MESSAGE_CAPACITY ||
        !disjoint(wire, sizeof *wire, slot->message, slot->message_capacity) ||
        !ism_pulse_decode_phase(slot->phase, &contexts[i].sc_phase))
      return ISM_PULSE_TABLE_INVALID;
    for (uint32_t j = 0; j < i; ++j) {
      if (wire->order[i] == wire->order[j] ||
          !disjoint(slot->message, slot->message_capacity,
                    wire->slots[j].message, wire->slots[j].message_capacity))
        return ISM_PULSE_TABLE_INVALID;
    }
    contexts[i].sc_id = slot->id;
    contexts[i].sc_buf = slot->message;
    order[i] = &contexts[wire->order[i]];
  }
  /* Genuine separate local references and pointer array, not casts of stable
   * contexts. Message pointers are framed and never dereferenced by this port. */
  DNS_Migration_PulseMultiplexer_connection_context conn = {
    .cc_active = order, .cc_num = wire->count, .cc_capacity = wire->capacity
  };
  if (operation == ISM_PULSE_TABLE_FIND)
    return DNS_Migration_PulseMultiplexer_find_stream(&conn, id);
  if (operation == ISM_PULSE_TABLE_ALLOCATE) {
    uint32_t result = DNS_Migration_PulseMultiplexer_allocate_stream(&conn, id);
    if (result < wire->capacity) {
      uint32_t physical = wire->order[result];
      wire->slots[physical].id = contexts[physical].sc_id;
      wire->slots[physical].phase = (ism_pulse_phase){.tag = ISM_PULSE_LENGTH};
      wire->count = conn.cc_num;
    }
    return result;
  }
  bool closed = DNS_Migration_PulseMultiplexer_close_stream(&conn, id);
  if (closed) {
    for (uint32_t i = 0; i < ISM_PULSE_TABLE_SLOTS; ++i)
      wire->order[i] = (uint32_t)(order[i] - contexts);
    wire->count = conn.cc_num;
  }
  return closed ? 1U : 0U;
}

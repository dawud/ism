#ifndef ISM_PULSE_TABLE_H
#define ISM_PULSE_TABLE_H

#include "ism_pulse_stream.h"

#define ISM_PULSE_TABLE_ABI_VERSION 1U
#define ISM_PULSE_TABLE_SLOTS 4U
#define ISM_PULSE_TABLE_FIND 0U
#define ISM_PULSE_TABLE_ALLOCATE 1U
#define ISM_PULSE_TABLE_CLOSE 2U
#define ISM_PULSE_TABLE_INVALID UINT32_MAX

/* Fixed physical identities; order[] is their mutable active/available
 * permutation. No generated type or context pointer crosses compiler lanes. */
typedef struct ism_pulse_table_slot_s {
  uint64_t id;
  ism_pulse_phase phase;
  uint8_t *message;
  size_t message_capacity;
} ism_pulse_table_slot;

typedef struct ism_pulse_table_s {
  ism_pulse_table_slot slots[ISM_PULSE_TABLE_SLOTS];
  uint32_t order[ISM_PULSE_TABLE_SLOTS];
  uint32_t count;
  uint32_t capacity;
} ism_pulse_table;

_Static_assert(sizeof(ism_pulse_table_slot) == 40 &&
               offsetof(ism_pulse_table_slot, message) == 24 &&
               offsetof(ism_pulse_table_slot, message_capacity) == 32,
               "table ABI requires reviewed native x86_64 layout");
_Static_assert(sizeof(ism_pulse_table) == 184 &&
               offsetof(ism_pulse_table, order) == 160 &&
               offsetof(ism_pulse_table, count) == 176 &&
               offsetof(ism_pulse_table, capacity) == 180,
               "unexpected table ABI layout");

uint32_t ism_pulse_table_abi_version(void);

/* Caller owns a live aligned table and four separate live message buffers,
 * with truthful capacities and exclusive access. No allocation, byte access,
 * retained pointer or ownership transfer. Checks cannot establish liveness.
 * FIND: first matching index, count on miss. ALLOCATE: old count on success,
 * capacity on duplicate/full rejection. CLOSE: 1 if removed, 0 if absent.
 * INVALID means an unsupported operation or invalid descriptor, with no writes.
 * Failure/miss changes nothing. Allocation updates only selected ID/phase and
 * count; close updates only permutation/count; message bytes never change. */
uint32_t ism_pulse_table_apply(ism_pulse_table *table, uint32_t operation, uint64_t id);

#endif

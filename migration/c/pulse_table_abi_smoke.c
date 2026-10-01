#include "ism_pulse_table.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK(x) do { if (!(x)) { fprintf(stderr, "table ABI check line %d: %s\n", __LINE__, #x); exit(1); } } while (0)

static uint8_t bytes[ISM_PULSE_TABLE_SLOTS][ISM_PULSE_MESSAGE_CAPACITY];
static ism_pulse_table wire, saved;

static void init(void)
{
  memset(&wire, 0, sizeof wire);
  wire.capacity = ISM_PULSE_TABLE_SLOTS;
  for (uint32_t i = 0; i < ISM_PULSE_TABLE_SLOTS; ++i) {
    wire.order[i] = i;
    wire.slots[i] = (ism_pulse_table_slot){.id = 99 + i,
      .phase = {.tag = ISM_PULSE_PROCESSING, .expected = 12 + i},
      .message = bytes[i], .message_capacity = sizeof bytes[i]};
    memset(bytes[i], (int)(0x70 + i), sizeof bytes[i]);
  }
}

static void rejected(uint32_t op)
{
  memcpy(&saved, &wire, sizeof wire);
  CHECK(ism_pulse_table_apply(&wire, op, 4) == ISM_PULSE_TABLE_INVALID);
  CHECK(memcmp(&wire, &saved, sizeof wire) == 0);
}

int main(void)
{
  CHECK(ism_pulse_table_abi_version() == ISM_PULSE_TABLE_ABI_VERSION);
  CHECK(ism_pulse_table_apply(NULL, ISM_PULSE_TABLE_FIND, 0) == ISM_PULSE_TABLE_INVALID);
  init(); rejected(99);
  init(); wire.capacity = UINT32_MAX; rejected(ISM_PULSE_TABLE_ALLOCATE);
  init(); wire.count = 5; rejected(ISM_PULSE_TABLE_CLOSE);
  init(); wire.order[3] = 0; rejected(ISM_PULSE_TABLE_ALLOCATE);
  init(); wire.order[3] = UINT32_MAX; rejected(ISM_PULSE_TABLE_FIND);
  init(); wire.slots[2].message = NULL; rejected(ISM_PULSE_TABLE_CLOSE);
  init(); wire.slots[2].message_capacity = 65534; rejected(ISM_PULSE_TABLE_ALLOCATE);
  init(); wire.slots[2].message_capacity = SIZE_MAX; rejected(ISM_PULSE_TABLE_FIND);
  init(); wire.slots[2].message = bytes[0]; rejected(ISM_PULSE_TABLE_CLOSE);
  init(); wire.slots[2].message = (uint8_t *)&wire; rejected(ISM_PULSE_TABLE_FIND);
  init(); wire.slots[3].phase.tag = UINT8_MAX; rejected(ISM_PULSE_TABLE_ALLOCATE);
  for (uint8_t tag = ISM_PULSE_BODY; tag <= ISM_PULSE_PROCESSING; ++tag) {
    init(); wire.slots[3].phase = (ism_pulse_phase){.tag = tag, .expected = 65536};
    rejected(ISM_PULSE_TABLE_FIND);
  }
  /* All representable phases, including typed invalid states, are preserved
   * on lookup/close; table operations do not reinterpret framing validity. */
  for (uint8_t tag = ISM_PULSE_LENGTH; tag <= ISM_PULSE_DONE; ++tag) {
    init(); wire.count = 4;
    wire.slots[0].phase = (ism_pulse_phase){.tag = tag, .expected = 0, .current = UINT32_MAX, .high = 255};
    memcpy(&saved, &wire, sizeof wire);
    CHECK(ism_pulse_table_apply(&wire, ISM_PULSE_TABLE_FIND, 99) == 0);
    CHECK(memcmp(&wire, &saved, sizeof wire) == 0);
    CHECK(ism_pulse_table_apply(&wire, ISM_PULSE_TABLE_CLOSE, 99) == 1);
    CHECK(wire.order[0] == 3 && wire.order[3] == 0 && wire.count == 3);
    CHECK(memcmp(wire.slots, saved.slots, sizeof wire.slots) == 0);
    CHECK(ism_pulse_table_apply(&wire, ISM_PULSE_TABLE_ALLOCATE, UINT64_MAX) == 3);
    CHECK(wire.slots[0].id == UINT64_MAX && wire.slots[0].phase.tag == ISM_PULSE_LENGTH);
    CHECK(wire.slots[0].message == bytes[0] && wire.count == 4);
    memcpy(&saved, &wire, sizeof wire);
    CHECK(ism_pulse_table_apply(&wire, ISM_PULSE_TABLE_ALLOCATE, 55) == 4);
    CHECK(memcmp(&wire, &saved, sizeof wire) == 0);
    for (uint32_t i = 0; i < ISM_PULSE_TABLE_SLOTS; ++i)
      for (uint32_t j = 0; j < ISM_PULSE_MESSAGE_CAPACITY; ++j)
        CHECK(bytes[i][j] == 0x70 + i);
  }
  init(); wire.count = 2;
  memcpy(&saved, &wire, sizeof wire);
  CHECK(ism_pulse_table_apply(&wire, ISM_PULSE_TABLE_ALLOCATE, 99) == 4);
  CHECK(ism_pulse_table_apply(&wire, ISM_PULSE_TABLE_CLOSE, 42) == 0);
  CHECK(memcmp(&wire, &saved, sizeof wire) == 0);
  init(); wire.capacity = 0;
  CHECK(ism_pulse_table_apply(&wire, ISM_PULSE_TABLE_ALLOCATE, 0) == 0);
  CHECK(wire.count == 0);
  puts("Pulse table neutral ABI smoke passed");
  return 0;
}

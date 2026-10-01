/* Standalone candidate test: no stable generated types cross this boundary.
 * The integer-index oracle supplements, and does not replace, the Pulse proofs.
 * Raw C callers must still establish the documented ownership preconditions. */
#include "DNS_Migration_PulseMultiplexer.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK(x) do { if (!(x)) { \
  fprintf(stderr, "table check failed at %s:%d: %s\n", __FILE__, __LINE__, #x); \
  exit(1); \
} } while (0)

enum { SLOTS = 4, BYTES = 65535 };
typedef DNS_Migration_PulseStream_stream_context Context;
typedef DNS_Migration_PulseMultiplexer_connection_context Connection;
typedef DNS_QUIC_StreamModel_stream_phase Phase;

static struct {
  uint8_t bytes[SLOTS][BYTES], original[SLOTS][BYTES];
  Context contexts[SLOTS], expected[SLOTS];
  Context *table[SLOTS];
  unsigned order[SLOTS];
  Connection conn;
  unsigned count, capacity;
} f;
static unsigned cases;

static int phase_equal(Phase a, Phase b)
{
  if (a.tag != b.tag) return 0;
  switch (a.tag) {
  case DNS_QUIC_StreamModel_Done:
  case DNS_QUIC_StreamModel_ReadingLength: return 1;
  case DNS_QUIC_StreamModel_ReadingLengthHigh:
    return a.case_ReadingLengthHigh == b.case_ReadingLengthHigh;
  case DNS_QUIC_StreamModel_ReadingMessage:
    return a.case_ReadingMessage.expected == b.case_ReadingMessage.expected &&
           a.case_ReadingMessage.current == b.case_ReadingMessage.current;
  case DNS_QUIC_StreamModel_AwaitingFin:
    return a.case_AwaitingFin == b.case_AwaitingFin;
  case DNS_QUIC_StreamModel_Processing:
    return a.case_Processing == b.case_Processing;
  default: return 0;
  }
}

static void initialize(const unsigned order[SLOTS], unsigned capacity,
                       unsigned count, int duplicate_ids)
{
  f.capacity = capacity;
  f.count = count;
  for (unsigned i = 0; i < SLOTS; ++i) {
    f.contexts[i] = (Context){
      .sc_id = (duplicate_ids ? i % 2 : i) * UINT64_C(4),
      .sc_phase = {.tag = DNS_QUIC_StreamModel_Processing, .case_Processing = 12 + i},
      .sc_buf = f.bytes[i]
    };
    f.expected[i] = f.contexts[i];
    f.table[i] = &f.contexts[order[i]];
    f.order[i] = order[i];
  }
  f.conn = (Connection){.cc_active = f.table, .cc_num = count, .cc_capacity = capacity};
}

static void check_state(void)
{
  CHECK(f.conn.cc_active == f.table);
  CHECK(f.conn.cc_num == f.count);
  CHECK(f.conn.cc_capacity == f.capacity);
  for (unsigned i = 0; i < SLOTS; ++i) {
    CHECK(f.table[i] == &f.contexts[f.order[i]]);
    CHECK(f.contexts[i].sc_id == f.expected[i].sc_id);
    CHECK(phase_equal(f.contexts[i].sc_phase, f.expected[i].sc_phase));
    CHECK(f.contexts[i].sc_buf == f.bytes[i]);
    CHECK(memcmp(f.bytes[i], f.original[i], BYTES) == 0);
  }
  ++cases;
}

/* 0 = lookup, 1 = reserve a preallocated slot, 2 = close. */
static void step(unsigned op, uint64_t id)
{
  unsigned found = 0;
  while (found < f.count && f.expected[f.order[found]].sc_id != id) ++found;
  switch (op) {
  case 0:
    CHECK(DNS_Migration_PulseMultiplexer_find_stream(&f.conn, id) == found);
    break;
  case 1: {
    unsigned result = f.capacity;
    if (found == f.count && f.count < f.capacity) {
      result = f.count++;
      f.expected[f.order[result]].sc_id = id;
      f.expected[f.order[result]].sc_phase = (Phase){.tag = DNS_QUIC_StreamModel_ReadingLength};
    }
    CHECK(DNS_Migration_PulseMultiplexer_allocate_stream(&f.conn, id) == result);
    break;
  }
  case 2: {
    int closed = found < f.count;
    if (closed) {
      unsigned removed = f.order[found];
      f.order[found] = f.order[--f.count];
      f.order[f.count] = removed;
    }
    CHECK(DNS_Migration_PulseMultiplexer_close_stream(&f.conn, id) == closed);
    break;
  }
  default: CHECK(0);
  }
  check_state();
}

int main(void)
{
  const uint64_t ids[] = {0, 4, 8, 12, 99, UINT64_MAX};
  for (unsigned i = 0; i < SLOTS; ++i)
    for (unsigned j = 0; j < BYTES; ++j)
      f.original[i][j] = f.bytes[i][j] = (uint8_t)(j * 17 + i * 31);

  /* Every permutation, capacity/prefix pair, first/middle/last/missing match,
   * duplicate IDs on distinct contexts, and full/zero-capacity rejection. */
  for (unsigned a = 0; a < SLOTS; ++a)
    for (unsigned b = 0; b < SLOTS; ++b)
      for (unsigned c = 0; c < SLOTS; ++c)
        for (unsigned d = 0; d < SLOTS; ++d) {
          if (a == b || a == c || a == d || b == c || b == d || c == d) continue;
          unsigned order[] = {a, b, c, d};
          for (unsigned cap = 0; cap <= SLOTS; ++cap)
            for (unsigned count = 0; count <= cap; ++count)
              for (int duplicate = 0; duplicate <= 1; ++duplicate)
                for (unsigned id = 0; id < sizeof(ids) / sizeof(ids[0]); ++id)
                  for (unsigned op = 0; op < 3; ++op) {
                    initialize(order, cap, count, duplicate);
                    step(op, ids[id]);
                  }
        }

  /* Chained mutations: retired-slot reuse, preservation of other active
   * contexts, self-swap at capacity one, repeated closes, and sentinel IDs. */
  const unsigned order[] = {0, 1, 2, 3};
  for (unsigned cap = 0; cap <= SLOTS; ++cap) {
    initialize(order, cap, 0, 0);
    for (unsigned round = 0; round < 32; ++round) {
      step(1, 0); step(1, UINT64_MAX); step(1, 4); step(1, 8);
      step(1, UINT64_MAX); step(1, 99); step(0, UINT64_MAX);
      step(2, 0); step(2, 0); step(1, 12); step(0, 12);
      step(2, UINT64_MAX); step(2, 4); step(2, 8); step(2, 12); step(2, 99);
    }
  }
  printf("Pulse table C smoke passed: %u state/byte comparisons\n", cases);
  return 0;
}

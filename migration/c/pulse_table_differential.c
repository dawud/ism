#include "pulse_stream_adapter.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void legacy_ism_shell_connection_init(ism_shell_connection *);
DNS_QUIC_StreamMapping_stream_context *legacy_ism_shell_find_stream(ism_shell_connection *, uint64_t);
DNS_QUIC_StreamMapping_stream_context *legacy_ism_shell_open_stream(ism_shell_connection *, uint64_t);
uint8_t legacy_ism_shell_dispatch_stream_reset(ism_shell_connection *, uint64_t);
uint8_t legacy_ism_shell_complete_response_send(ism_shell_connection *, uint64_t, uint8_t *, uint32_t, bool);
uint8_t legacy_ism_shell_dispatch_response_send_finished(ism_shell_connection *, uint64_t, uint8_t *, uint32_t, bool);
uint8_t legacy_ism_shell_on_authenticated_stream_data(ism_shell_connection *, uint64_t, uint8_t *, uint32_t);
uint8_t legacy_ism_shell_on_authenticated_stream_fin(ism_shell_connection *, uint64_t);

#define CHECK(x) do { if (!(x)) { fprintf(stderr, "table differential line %d: %s\n", __LINE__, #x); exit(1); } } while (0)
static ism_shell_connection old, candidate, saved;
static uint8_t response[1];
static unsigned comparisons;

static unsigned physical(ism_shell_connection *c, DNS_QUIC_StreamMapping_stream_context *p)
{
  if (p == NULL) return ISM_SHELL_MAX_STREAMS;
  for (unsigned i = 0; i < ISM_SHELL_MAX_STREAMS; ++i)
    if (p == &c->streams[i].ctx) return i;
  CHECK(0); return 0;
}

static void compare(void)
{
  CHECK(old.ctx.cc_num == candidate.ctx.cc_num && old.ctx.cc_capacity == candidate.ctx.cc_capacity);
  CHECK(old.ctx.cc_active == old.active && candidate.ctx.cc_active == candidate.active);
  for (unsigned i = 0; i < ISM_SHELL_MAX_STREAMS; ++i) {
    CHECK(physical(&old, old.active[i]) == physical(&candidate, candidate.active[i]));
    CHECK(old.streams[i].active == candidate.streams[i].active);
    CHECK(old.streams[i].ctx.sc_id == candidate.streams[i].ctx.sc_id);
    ism_pulse_phase a = ism_pulse_phase_to_wire(old.streams[i].ctx.sc_phase);
    ism_pulse_phase b = ism_pulse_phase_to_wire(candidate.streams[i].ctx.sc_phase);
    CHECK(a.tag == b.tag && a.high == b.high && a.expected == b.expected && a.current == b.current);
    CHECK(old.streams[i].ctx.sc_buf == old.streams[i].message_buffer);
    CHECK(candidate.streams[i].ctx.sc_buf == candidate.streams[i].message_buffer);
    CHECK(memcmp(old.streams[i].message_buffer, candidate.streams[i].message_buffer,
                 ISM_SHELL_STREAM_BUFFER_SIZE) == 0);
  }
  ++comparisons;
}

static void initialize(unsigned *order, unsigned capacity, unsigned count, bool duplicates)
{
  legacy_ism_shell_connection_init(&old);
  ism_shell_connection_init(&candidate);
  ism_shell_connection *both[] = {&old, &candidate};
  for (unsigned n = 0; n < 2; ++n) {
    ism_shell_connection *c = both[n];
    c->ctx.cc_num = count; c->ctx.cc_capacity = capacity;
    for (unsigned i = 0; i < ISM_SHELL_MAX_STREAMS; ++i) {
      c->active[i] = &c->streams[order[i]].ctx;
      c->streams[order[i]].active = i < count;
      c->streams[i].ctx.sc_id = (duplicates ? i % 2 : i) * UINT64_C(4);
      c->streams[i].ctx.sc_phase = (DNS_QUIC_StreamMapping_stream_phase){
        .tag = DNS_QUIC_StreamMapping_Processing, .case_Processing = 12 + i};
      memset(c->streams[i].message_buffer, (int)(0x70 + i), ISM_SHELL_STREAM_BUFFER_SIZE);
    }
  }
}

static void step(unsigned op, uint64_t id)
{
  switch (op) {
  case 0:
    CHECK(physical(&old, legacy_ism_shell_find_stream(&old, id)) ==
          physical(&candidate, ism_shell_find_stream(&candidate, id))); break;
  case 1:
    CHECK(physical(&old, legacy_ism_shell_open_stream(&old, id)) ==
          physical(&candidate, ism_shell_open_stream(&candidate, id))); break;
  case 2:
    CHECK(legacy_ism_shell_dispatch_stream_reset(&old, id) ==
          ism_shell_dispatch_stream_reset(&candidate, id)); break;
  case 3: case 4:
    CHECK(legacy_ism_shell_complete_response_send(&old, id, response, 1, op == 4) ==
          ism_shell_complete_response_send(&candidate, id, response, 1, op == 4)); break;
  case 5: case 6:
    CHECK(legacy_ism_shell_dispatch_response_send_finished(&old, id, response, 1, op == 6) ==
          ism_shell_dispatch_response_send_finished(&candidate, id, response, 1, op == 6)); break;
  default: CHECK(0);
  }
  compare();
}

static void rejected_shell(void)
{
  memcpy(&saved, &candidate, sizeof saved);
  CHECK(ism_shell_find_stream(&candidate, 0) == NULL);
  CHECK(ism_shell_open_stream(&candidate, 0) == NULL);
  CHECK(ism_shell_dispatch_stream_reset(&candidate, 0) == 0);
  CHECK(ism_shell_complete_response_send(&candidate, 0, response, 1, false) == 0);
  CHECK(ism_shell_dispatch_response_send_finished(&candidate, 0, response, 1, true) == 0);
  CHECK(memcmp(&saved, &candidate, sizeof saved) == 0);
}

int main(void)
{
  uint64_t ids[] = {0, 4, 8, 12, 99, UINT64_MAX};
  for (unsigned a = 0; a < 4; ++a) for (unsigned b = 0; b < 4; ++b)
    for (unsigned c = 0; c < 4; ++c) for (unsigned d = 0; d < 4; ++d) {
      if (a == b || a == c || a == d || b == c || b == d || c == d) continue;
      unsigned order[] = {a,b,c,d};
      for (unsigned cap = 0; cap <= 4; ++cap) for (unsigned count = 0; count <= cap; ++count)
        for (unsigned dup = 0; dup <= 1; ++dup) for (unsigned id = 0; id < 6; ++id)
          for (unsigned op = 0; op < 7; ++op) {
            initialize(order, cap, count, dup != 0); step(op, ids[id]);
          }
    }
  unsigned order[] = {0,1,2,3};
  for (unsigned cap = 0; cap <= 4; ++cap) {
    initialize(order, cap, 0, false);
    for (unsigned round = 0; round < 32; ++round) {
      step(1,0); step(1,UINT64_MAX); step(1,4); step(1,8); step(1,0); step(1,99);
      step(2,0); step(2,0); step(1,12); step(0,12);
      step(3,UINT64_MAX); step(4,4); step(5,8); step(6,12); step(2,99);
    }
  }
  /* Full ingress/FIN -> close/reuse composition on the actual selected shell. */
  uint8_t request[14] = {0,12};
  initialize(order, 4, 0, false);
  for (unsigned i = 0; i < 64; ++i) {
    CHECK(legacy_ism_shell_on_authenticated_stream_data(&old, i, request, sizeof request) ==
          ism_shell_on_authenticated_stream_data(&candidate, i, request, sizeof request));
    compare();
    CHECK(legacy_ism_shell_on_authenticated_stream_fin(&old, i) ==
          ism_shell_on_authenticated_stream_fin(&candidate, i));
    compare(); step(i % 5 + 2, i);
  }
  /* Corrupt descriptors are outside the baseline contract. Check only the new
   * adapter, and require failure before it mutates any shell storage. */
  ism_shell_connection_init(&candidate); candidate.ctx.cc_num = 5; rejected_shell();
  ism_shell_connection_init(&candidate); candidate.ctx.cc_capacity = 5; rejected_shell();
  ism_shell_connection_init(&candidate); candidate.ctx.cc_active = NULL; rejected_shell();
  ism_shell_connection_init(&candidate); candidate.active[3] = candidate.active[0]; rejected_shell();
  ism_shell_connection_init(&candidate); candidate.active[3] = NULL; rejected_shell();
  ism_shell_connection_init(&candidate); candidate.streams[0].active = true; rejected_shell();
  ism_shell_connection_init(&candidate); candidate.streams[0].ctx.sc_buf = NULL; rejected_shell();
  ism_shell_connection_init(&candidate); candidate.streams[0].ctx.sc_phase.tag = 99; rejected_shell();
  ism_shell_connection_init(&candidate);
  candidate.streams[0].ctx.sc_phase = (DNS_QUIC_StreamMapping_stream_phase){
    .tag = DNS_QUIC_StreamMapping_AwaitingFin, .case_AwaitingFin = 65536}; rejected_shell();
  printf("Pulse/baseline shell table differential: %u comparisons passed\n", comparisons);
  return 0;
}

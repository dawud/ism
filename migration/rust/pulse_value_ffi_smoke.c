#include <stdint.h>

#define DNS_PULSE_PHASE_READING 0u
#define DNS_PULSE_PHASE_PROCESSING 1u
#define DNS_PULSE_PHASE_CLOSED 2u

typedef struct DnsPulseStreamState {
  uint32_t buffered;
  uint32_t capacity;
  uint32_t phase;
} DnsPulseStreamState;

typedef struct DnsPulseDispatchResult {
  uint8_t accepted;
  DnsPulseStreamState next;
} DnsPulseDispatchResult;

extern uint32_t dns_pulse_available(DnsPulseStreamState state);
extern uint8_t dns_pulse_accepts_fragment(DnsPulseStreamState state, uint32_t len);
extern DnsPulseDispatchResult dns_pulse_dispatch_authenticated_bytes(
    DnsPulseStreamState state,
    uint32_t len);

int main(void) {
  DnsPulseStreamState initial = {4u, 12u, DNS_PULSE_PHASE_READING};
  if (dns_pulse_available(initial) != 8u) return 1;
  if (dns_pulse_accepts_fragment(initial, 8u) != 1u) return 2;

  DnsPulseDispatchResult accepted =
      dns_pulse_dispatch_authenticated_bytes(initial, 8u);
  if (accepted.accepted != 1u) return 3;
  if (accepted.next.buffered != 12u) return 4;
  if (accepted.next.phase != DNS_PULSE_PHASE_PROCESSING) return 5;

  DnsPulseDispatchResult rejected =
      dns_pulse_dispatch_authenticated_bytes(accepted.next, 1u);
  if (rejected.accepted != 0u) return 6;
  if (rejected.next.phase != DNS_PULSE_PHASE_CLOSED) return 7;

  DnsPulseStreamState invalid_phase = {0u, 1u, 99u};
  DnsPulseDispatchResult invalid =
      dns_pulse_dispatch_authenticated_bytes(invalid_phase, 2u);
  if (invalid.accepted != 0u) return 8;
  if (invalid.next.phase != DNS_PULSE_PHASE_CLOSED) return 9;

  return 0;
}

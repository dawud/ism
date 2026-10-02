#ifndef ISM_PULSE_RESPONSE_H
#define ISM_PULSE_RESPONSE_H

#include <stddef.h>
#include <stdint.h>

#define ISM_PULSE_RESPONSE_ABI_VERSION 1U

uint32_t ism_pulse_response_abi_version(void);

/* Synchronous byte framing only; no descriptor, FIN, send or retained pointer.
 * Caller owns live, separate source/destination storage of the declared sizes
 * exclusively for this call. Source length and writable capacity must fit those
 * sizes. Source is unchanged, as is destination beyond the returned length.
 * Null source is accepted only for zero source capacity/length (local empty
 * borrow); destination must be non-null even on a zero-capacity rejection.
 * Invalid descriptors, overlapping/wrapped ranges, length > 65535 or capacity
 * < length + 2 return zero without writes. Empty success returns two.
 * Range checks do not prove allocation provenance, truthful sizes or ownership.
 */
uint32_t ism_pulse_response_frame(
  uint8_t *response, size_t response_capacity, uint32_t length,
  uint8_t *destination, size_t destination_capacity, uint32_t capacity);

#endif

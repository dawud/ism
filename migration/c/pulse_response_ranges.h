#ifndef ISM_PULSE_RESPONSE_RANGES_H
#define ISM_PULSE_RESPONSE_RANGES_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* Descriptor checks for the reviewed flat-address native C target, not a proof
 * of live allocations. Empty ranges carry no bytes and cannot overlap. */
_Static_assert(sizeof(size_t) >= sizeof(uint32_t), "response ABI needs 32-bit size_t");
_Static_assert(sizeof(uintptr_t) == sizeof(size_t), "unexpected native address width");

static inline bool ism_response_range_ok(const void *p, size_t n)
{
  return p != NULL && n <= UINTPTR_MAX - (uintptr_t)p;
}

static inline bool ism_response_disjoint(const void *a, size_t an, const void *b, size_t bn)
{
  uintptr_t ap = (uintptr_t)a, bp = (uintptr_t)b;
  return ism_response_range_ok(a, an) && ism_response_range_ok(b, bn) &&
    (an == 0 || bn == 0 || ap + an <= bp || bp + bn <= ap);
}

#endif

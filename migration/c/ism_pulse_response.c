#include "ism_pulse_response.h"
#include "pulse_response_ranges.h"
#include "DNS_Migration_PulseResponse.h"

uint32_t ism_pulse_response_abi_version(void)
{
  return ISM_PULSE_RESPONSE_ABI_VERSION;
}

uint32_t ism_pulse_response_frame(
  uint8_t *response, size_t response_capacity, uint32_t length,
  uint8_t *destination, size_t destination_capacity, uint32_t capacity)
{
  if (length > response_capacity || capacity > destination_capacity ||
      !ism_response_range_ok(destination, destination_capacity)) return 0U;
  uint8_t empty = 0U;
  if (response_capacity == 0) response = &empty;
  if (!ism_response_disjoint(response, response_capacity, destination, destination_capacity))
    return 0U;
  /* The checked implementation owns these separate arrays for the duration of
   * the call. Real liveness, sizes and exclusivity are still caller obligations. */
  return DNS_Migration_PulseResponse_frame_response(response, destination, length, capacity);
}

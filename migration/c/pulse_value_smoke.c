/* Toolchain smoke only: this pilot does not implement the DoQ lifecycle.
 * Use the generated header, not a handwritten duplicate of its ABI. */
#include <assert.h>
#include <stdint.h>
#include "DNS_Migration_PulseShellBoundaryValue.h"

typedef DNS_Migration_PulseShellBoundaryValue_stream_state state;
typedef DNS_Migration_PulseShellBoundaryValue_dispatch_result result;

int main(void)
{
    state initial = {4, 12, DNS_Migration_PulseShellBoundaryValue_ValueReading};
    result accepted =
        DNS_Migration_PulseShellBoundaryValue_dispatch_authenticated_bytes_value(initial, 3);
    assert(accepted.accepted);
    assert(accepted.next.buffered == 7);
    assert(accepted.next.capacity == 12);
    assert(accepted.next.phase == DNS_Migration_PulseShellBoundaryValue_ValueProcessing);

    result rejected =
        DNS_Migration_PulseShellBoundaryValue_dispatch_authenticated_bytes_value(initial, 9);
    assert(!rejected.accepted);
    assert(rejected.next.buffered == 4);
    assert(rejected.next.capacity == 12);
    assert(rejected.next.phase == DNS_Migration_PulseShellBoundaryValue_ValueClosed);

    state near_limit = {UINT32_MAX - 1, UINT32_MAX,
                        DNS_Migration_PulseShellBoundaryValue_ValueReading};
    result exact =
        DNS_Migration_PulseShellBoundaryValue_dispatch_authenticated_bytes_value(near_limit, 1);
    assert(exact.accepted && exact.next.buffered == UINT32_MAX);
    result overflow =
        DNS_Migration_PulseShellBoundaryValue_dispatch_authenticated_bytes_value(near_limit, 2);
    assert(!overflow.accepted && overflow.next.buffered == UINT32_MAX - 1);
    return 0;
}

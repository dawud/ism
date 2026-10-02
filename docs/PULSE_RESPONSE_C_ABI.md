# Mixed Pulse response framing boundary (M4)

`make pulse-response-integration-check` adds Pulse response framing to the
existing ingress/FIN and table lifecycle selections. It compiles the actual
shell with `ISM_USE_PULSE_RESPONSE=1`, checks the selected symbols, and runs the
same C and MsQuic gates on that shell object. Default stable, M3 ingress-only,
and M4 table-enabled lanes remain unchanged. See DR-0024.

This replaces only synchronous length-prefix/payload copying. DNS response
construction, the stable send-descriptor handoff, runtime submission, FIN flags,
single in-flight-send bookkeeping, completion notification and buffer lifetime
are not replaced or newly proved. The framing theorem does not justify reusing
storage before MsQuic completes or drops the send.

## Neutral ABI and byte semantics

`migration/c/ism_pulse_response.h` defines native C ABI version 1. It passes only
byte pointers, `size_t` allocation/slice capacities and uint32 lengths; no
generated context, descriptor, array wrapper or enum crosses compiler lanes.
Both sides require a flat-address target with `sizeof(size_t) >= 4` and matching
`size_t`/`uintptr_t` widths; manifests require matching C compiler target triples.
The evaluated target is Linux x86_64, not a wire encoding or a portability proof.

`ism_pulse_response_frame(response, response_capacity, length, destination,
destination_capacity, capacity)` returns:

- `length + 2` on success: two big-endian length bytes followed by the exact
  input prefix. All source bytes and destination bytes after the frame stay
  unchanged, including the tail outside the writable `capacity`.
- Zero, without writes, if length exceeds 65535 or writable capacity is short.
  The generated helper checks the length bound before adding two.
- Zero, without calling the generated function, for invalid descriptors:
  lengths exceeding declared sizes, null nonempty source, null destination,
  wrapping address ranges or overlap of the complete declared byte slices.

Empty success returns two zero bytes, preserving the stable behavior. A null
source is allowed only with zero source capacity and length; the adapter uses
a local non-null empty borrow. Empty ranges cannot overlap. Nonempty adjacent
borrows from the same allocation are allowed when their declared ranges do not
overlap. Returning zero for invalid descriptors is defensive C behavior, not a
claim that invalid pointers satisfy a Pulse precondition.

## Adapter and ownership review

`migration/c/ism_pulse_response.c` includes only candidate generated headers.
It validates the descriptors and calls the extracted `PulseResponse` array
implementation. `shell/pulse_response_adapter.c` includes only stable generated
headers and the neutral ABI. It checks ABI identity and destination/context
separation before any write, then borrows the source prefix of `response_len`
bytes and the destination slice of `stream_capacity` bytes exposed by the
existing shell API. It rejects a null context/message pointer and passes the
framed length, same context and unchanged FIN code through the existing
`prepare_response_send_for_stream` descriptor handoff. Missing stream lookup
still returns zero. No phase restriction is added to framing.

Both adapters, and their shared native range-check helpers, are **unverified
trusted C**. The caller must supply live aligned context/message storage,
truthful buffer sizes, separate source/destination/context where required,
exclusive access for the call and serialized callbacks. Range checks cannot
establish allocation provenance, bounds of forged descriptors, authentication
or ownership. Only the used source prefix is exposed by the shell API; bytes
beyond it are neither read nor written. No allocation, free, context relocation,
persistent shadow storage or retained pointer is introduced by framing.

Pulse verifies the owned array operation, not the C caller or a cross-compiler
heap correspondence. After framing, the existing runtime must keep the send
buffer live and immutable until matching completion/drop. Unit borrow tokens,
descriptor/completion lifetime proofs and production synchronization remain
open. Tests of FIN values check preserved observed behavior; they are not a new
formal asynchronous send theorem.

## Extraction, integration gates and rollback

`candidate-response-c-smoke`, required by `candidate-check`, runs all response
proofs first, then checked F* extraction without `--lax`, retaining cross-module
inlining and bundled Pulse primitives. F* extraction warning 250 and KaRaMeL
warnings 2/4/15 are fatal; new C components compile with `-Wall -Wextra -Werror`.
The output is a bounded native copy loop and integer operations; proof snapshots
and ownership erase. There is no recursive payload copy, allocator or assumed
Pulse runtime shim in this generated response function.

Direct generated-C and neutral-ABI tests compare complete byte arrays against
an independent framing oracle and check malformed descriptors separately.
`libism_pulse_response.a` contains only the generated implementation and neutral
adapter. Its manifest hashes source/build inputs and products and checks tool
pins, target, archive members and unexpected runtime dependencies. These checks
detect accidental drift, not malicious provenance.

The response-enabled integration lane checks shell/adapter symbols for actual
Pulse selection, absence of legacy framing/copy calls and retention of the
stable descriptor handoff. It compares against a separate compilation of the
actual baseline shell with all Pulse flags disabled, including missing IDs,
every phase, FIN values, exact/short/max lengths, all source/destination bytes,
guards and complete connection preservation. Invalid C descriptors are not
passed to the baseline outside its preconditions. Existing stream/table
differentials, callback/reset/completion tests and live MsQuic loopback gates
remain required. No candidate headers or checked/`.krml` files enter stable
compilation. Artifacts use `pulse-response/` within the candidate lane and
`dist/pulse-response-integration-v2026.09.13/` with a matching `obj/` directory.

A separate handoff smoke links the actual response adapter and candidate archive
with a **test-only** descriptor observer. It checks the exact context, pointer,
framed length and FIN code and requires no handoff on rejection. That observer
is not linked into the differential, callback or live-loopback binaries, which
retain the real stable descriptor implementation. It is regression evidence,
not an assumed production implementation or proof of asynchronous ownership.

Rollback is selecting the ordinary stable targets, `pulse-integration-check`,
or `pulse-table-integration-check` without the response flag. Stable pins and
the public generated shell/response ABI remain unchanged. M4 descriptor/
completion and other imperative ports, and M5 toolchain promotion, remain open.

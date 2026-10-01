# Mixed Pulse table lifecycle boundary (M4)

`make pulse-table-integration-check` selects Pulse for shell lookup/open and
the close performed by reset, direct completion and dispatched completion. It
also selects the existing Pulse ingress/FIN path. Default stable builds and
the separate M3 `pulse-integration-check` retain the original table lifecycle.
The public shell/context layout and stable pins do not change. See DR-0022.

This is table lifecycle integration, not the remaining egress, worker, scheduler
or parser proof migration. The Low* response-worker wrappers still perform
their internal read-only table lookups against the coherent stable table.
Send-buffer lifetime, authentication and callback serialization remain trusted
runtime responsibilities. No old proof root or interface is retired.

## Representation and operations

`migration/c/ism_pulse_table.h` defines a native Linux x86_64 ABI, version 1,
with four physical slot identities. This deliberate bound matches
`ISM_SHELL_MAX_STREAMS`; changing it requires a reviewed ABI/layout update.
It is not a network encoding or a general variable-capacity API.

Each slot contains a uint64 ID, the neutral M3 phase, message pointer and size_t
capacity. Slot size is 40 bytes (message offset 24, capacity offset 32). A table
contains four slots, four uint32 permutation indices, uint32 count and uint32
capacity: 184 bytes, with order/count/capacity at offsets 160/176/180. Both sides
assert the layout, and artifact checks require matching C targets.

| Call | Return / mutation |
| --- | --- |
| FIND | First matching active index; count on miss; no mutation |
| ALLOCATE | Old count on success; capacity on duplicate/full rejection; success resets only the selected physical slot's ID/phase and increments count |
| CLOSE | 1 when removed, 0 when absent; success swaps first match with last active slot and decrements count; contexts unchanged |
| Invalid descriptor or operation | UINT32_MAX; no mutation |

All indices 0–3 occur exactly once in the complete permutation, including the
available suffix. `count <= capacity <= 4`. The stable adapter maps these
indices to the existing embedded context addresses, never to candidate pointers.
The neutral phase codes are the named conversions in [PULSE_C_ABI.md](PULSE_C_ABI.md),
not either compiler's generated constructor tags. The candidate decoder is
shared with the stream adapter; typed invalid but representable phases retain
their existing meaning (for example `AwaitingFin 0`).

## Ownership and writeback review

`shell/pulse_table_adapter.c` includes only stable generated types and the neutral
ABI. It validates the connection's embedded table pointer, bounded counts, full
pointer permutation, embedded buffer identity and agreement of `active` flags
with the active prefix. It reads context fields from the physical embedded pool,
not by dereferencing unrecognized table entries. Initialization still occurs in
`ism_shell_connection_init`: every context points to its own 65535-byte message
buffer and the complete table starts as the identity permutation.

`migration/c/ism_pulse_table.c` includes only candidate generated types. It
validates bounds, permutation, phase representability, capacities, pointer-range
overflow, pairwise message separation and separation from the neutral descriptor.
It constructs distinct stack-local candidate contexts and a real pointer array,
then calls the extracted Pulse operations with these resources. It never reads
or writes message bytes. There is no heap allocation, free, persistent shadow
table, retained pointer, or pointer cast between generated context layouts.

The adapters are unverified C. Raw callers must still provide real live aligned
storage, truthful capacities and exclusive access. Checks cannot prove allocation
provenance, authentication or synchronization. The Pulse theorem applies to the
candidate's local owned table/context heap; the mapping and writeback to persistent
shell storage are reviewed/tested trusted code, not a cross-heap correspondence
proof. All four message buffers remain caller-owned, even with count zero.

Writeback is deliberately limited:

- Lookup writes nothing. Shell open first looks up the ID, retaining idempotent
  open semantics even though the underlying allocation primitive rejects duplicates.
- Successful open updates only the selected stable context's ID/phase, its active
  flag and the connection count. The address and message-buffer pointer do not move.
- Close writes only the stable pointer permutation and count. The existing shell
  synchronization immediately resets retired slots and updates active flags before
  another operation can observe the temporary bookkeeping mismatch. Message bytes
  remain untouched. Reset synchronizes even on a miss; completion synchronizes
  when the matching active context existed, preserving the old behavior.
- Reset/completion return 1 for a valid table even when no matching ID exists.
  Invalid descriptors return 0 (find/open return NULL) without shell mutation.
  This rejection behavior is tested separately, not compared to invalid baseline
  calls outside their preconditions.

The old completion implementation ignores the completed/dropped distinction for
table cleanup and does not access response bytes: both outcomes close by ID and
return 1. The selected C dispatch preserves that behavior, while runtime response
storage and callback lifetimes remain unchanged. This does not prove that the
response buffer has been released at the right time or add a completion token.
Sequential caller ownership and the full response-descriptor contract remain
requirements pending the next egress/completion proof slice.

## Gates, resource scope and rollback

`candidate-check` retains direct generated-table tests and adds neutral-ABI
rejection/phase/writeback tests, a separately compiled `libism_pulse_table.a`
and `table-manifest.json`. Source/product hashes, pinned tool identities, C target,
archive membership and unresolved-symbol checks reject accidental stale/mixed
artifacts or unexpected runtime shims; they are not a supply-chain authenticity
proof. Stream and table products use separate private output directories.

`pulse-table-integration-check` runs stable verification/extraction/EverParse,
checks both manifests and compiles the table adapter against stable headers.
Compiled-object guards require shell references to Pulse find/open/close, reject
legacy reset/completion calls, and require the adapter to call the candidate ABI.
These guards do not claim removal of the remaining worker-internal Low* lookups.
The exact selected shell object is used for differential, C and all MsQuic tests.

`legacy_shell_oracle.c` independently compiles the actual baseline shell with
renamed public symbols and both Pulse flags disabled. Differential tests compare
returned physical context identities, full permutations/counts, phases, active
flags, buffer identity and every message byte. They include all four-slot
permutations/capacities/prefixes, duplicate IDs, idempotent open, reset/completion,
close/reuse and ingress/FIN composition. The old path is not called on deliberately
malformed descriptors. Tests support the review; they do not verify the adapters.

The snapshot is 184 bytes; generated contexts/pointer arrays and validation
bookkeeping are bounded by four slots. No 65535-byte message copy is added by
table operations. This is a structural resource review, not a latency/throughput
benchmark or proof of whole-runtime memory ownership.

Run `candidate-check` in the candidate image, then `pulse-table-integration-check`
in the stable image on the same checkout. Outputs use
`dist/pulse-table-integration-v2026.09.13/` and the corresponding `obj/` directory.
Use ordinary stable targets to roll back both substitutions, or the separate
`pulse-integration-check` to retain Pulse ingress/FIN only. Neither default tool
pins nor the normal build are promoted. Remaining M4 modules and M5 remain open.

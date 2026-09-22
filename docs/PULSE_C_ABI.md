# Mixed Pulse/Low* stream C boundary (M3)

M3 replaces stream ingress and FIN in an explicit integration lane, not the
default build. The existing shell API, context/table layout, worker, response,
reset and completion paths remain unchanged. `make pulse-integration-check`
selects Pulse for both shell data entry points and FIN; ordinary stable targets
remain Low*. See [DR-0020](DECISIONS.md#dr-0020-integrate-the-pulse-stream-port-through-a-versioned-c-only-boundary).

## Artifact and call boundaries

The candidate bundle verifies the shared model and real Pulse implementation,
then extracts those modules with `Pulse.Lib.Pervasives` using F*'s checked
extraction pass and default cross-module inlining. The library helper is from
the pinned bundle, not a new assumed runtime primitive. `--no_cmi` cannot be
used here. Executable `SizeT.uint32_to_sizet` conversions replace the model-only
conversion; the same proven bounds justify them. No source contract is weakened.

The generated C and candidate marshaler compile with candidate headers into
`libism_pulse_stream.a`. The stable-side marshaler and shell compile with only
stable generated headers and the neutral `migration/c/ism_pulse_stream.h`.
Only the C archive and neutral ABI join the builds: no generated struct casts,
shared checked files, mixed `.krml` inputs or candidate-generated headers in
stable translation units.

The actual selected receive path is:

```text
MsQuic callback → copy into runtime-owned ingress_buffer → queue + synchronous dispatch
  → C shell → stable-layout marshaler → neutral C ABI → candidate-layout marshaler
  → extracted Pulse handle_stream_data
FIN event → queue + dispatch → same C boundary → extracted Pulse handle_stream_fin
```

The queue must be empty before copying into the reusable ingress buffer. The
existing runtime checks this, bounds the copy and dispatches immediately.
Caller serialization remains required; this is not a proof that callbacks
cannot race. The direct shell data API likewise requires exclusively owned
input, not a merely shared read-only pointer.

## ABI version 1

This is a native Linux x86_64 C ABI, not a serialized/network format. The two
compilers must report the same C target. `ism_pulse_phase` contains `uint32_t`
`expected/current`, then `uint8_t` `tag/high`; its size is 12 bytes and tag
offset 8. `ism_pulse_result` contains that phase plus a `uint8_t` shell result
code (offset 12, total size 16). Both sides assert the layout. The stream ID is
`uint64_t`, fragment length is `uint32_t`, capacities are `size_t` (at least
32 bits). Unused fields are zero initialized; padding is not compared or sent.

| Neutral tag | Phase fields | Existing shell result code |
| --- | --- | --- |
| 0 | ReadingLength | 0 |
| 1 | ReadingLengthHigh: high | 0 |
| 2 | ReadingMessage: expected, current | 1 |
| 3 | AwaitingFin: expected | 4 |
| 4 | Processing: expected | 2 |
| 5 | Done | 3 |

The candidate's generated enum values differ from the stable ones. Both
marshalers switch on named constructors; neither casts raw generated unions
or assumes enum equivalence. The shell checks the runtime ABI version before
calling and updates only `sc_phase`. `sc_id` and `sc_buf` remain unchanged.

## Ownership, lifetime and rejection

The C adapters are reviewed and tested, **not verified**. The caller supplies
real, live, correctly aligned storage with truthful capacities and exclusive
access for the duration of each call. Context, message and input storage must
be disjoint. Pointer checks cannot establish allocation provenance, liveness,
authentication, or synchronization.

- Data requires at least 65535 message bytes and `len <= input_capacity`.
  The candidate marshaler checks nonnull/range overflow and message/input
  non-overlap using the supported flat-address representation. The stable
  marshaler supplies the shell's fixed message capacity and input length;
  it cannot validate that a caller's allocation is really that large.
- Zero-length input uses a distinct local byte and does not dereference the
  caller's input pointer. FIN requires two message bytes and leaves them intact.
- A stack-local candidate context supplies a separate reference. There is no
  allocation, free, escaped/retained pointer, delayed borrow or ownership transfer.
  Input bytes and message bytes outside the copy plan remain unchanged.
- Unknown raw tags, expected lengths above 65535, invalid descriptors and
  mismatched shell stream IDs reject to Done/code 3. Descriptor rejection occurs
  before message/input mutation. This is not a guarantee about forged pointers.
- Historically representable but invalid typed states retain their behavior:
  zero-ID FIN on `AwaitingFin 0` yields `Processing 0`; invalid body counts reject.
  A protocol-rejected fragment can copy a bounded body prefix before Done,
  exactly as specified in the shared model. Do not generalize the descriptor
  rejection rule to all protocol errors.

The Pulse postconditions and stable model-correspondence proofs apply under
their respective ownership/liveness preconditions. C review and tests support
the connection between them; no theorem currently verifies the C marshalers or
the complete callback ownership trace. MsQuic authentication, table lifecycle,
worker/send storage and serialized scheduling keep their existing trust limits.

## Extraction review and gates

Reviewed output uses native uint8/32/64 integers, pointers, a bounded `size_t`
copy loop and local context copies. Ghost arrays, ownership predicates and
validity lemmas erase; no heap allocator, GC, missing Pulse runtime primitive or
proof evaluator is linked. Each copy is at most 65535 bytes; local adapter
storage is constant size. This is a structural review, not a throughput or
whole-server resource benchmark. F* extraction warning 250 and KaRaMeL warnings
2/4/15 are fatal for this real-port extraction; new C translation units compile
with `-Wall -Wextra -Werror`. Existing stable extraction/C warning debt remains.

`candidate-check` requires proof tests, standalone C tests, and the inventory.
The standalone C test covers every split of a minimal framed message, early and
repeated FIN, excess bytes, short/max lengths, ID bytes, copied/input/guard bytes,
terminal/invalid states and rejected buffer descriptors. It is separate from
the original value pilot.

`check_stream_artifacts.py` hashes candidate source/build inputs and C products,
records the toolchain lock/provenance/target, rejects stale artifacts and checks
archive membership and unresolved runtime symbols. It detects accidental build
drift, not malicious artifacts or an untrusted manifest generator. It also
checks the actual compiled shell object references Pulse data/FIN and no legacy
ingress/FIN entry points; that same object is used by the mixed runtime tests.

`pulse-integration-check` requires stable verification/extraction and EverParse,
then runs 1071 differential state/byte/FIN comparisons and the existing C audit
and all MsQuic smoke gates, including callback and live loopback exchange.
Generated-header ABI assertions and explicit conversions preserve the existing
public shell types. Both toolchain lanes remain required in CI; hosted CI and
branch-protection configuration are distinct from locally executed evidence.

## Reproduce and roll back

Follow the two-container commands in [README.md](../README.md): first
`candidate-check` in the candidate image, then `pulse-integration-check` in the
stable image, on the same checkout. Rebuild the candidate archive if its manifest
rejects changed sources. Artifact directories are separate from stable output.

Rollback means using the ordinary stable targets, without `ISM_USE_PULSE_STREAM`
or `SHELL_INGRESS_*` overrides; the default implementation and pins never changed.
Remaining imperative ports, whole-project candidate verification and stable
promotion are M4/M5. Rust is outside these C-path gates.

# Pulse migration contract and ABI inventory

M1 baseline: `b51de95`, reviewed 2026-09-19. This is a migration checklist, not
a claim that these modules already work on the candidate compiler. No source,
interface, or proof is retired by this inventory. M2–M4 must preserve the written
contracts, not just this summary. See [DR-0017](DECISIONS.md#dr-0017-migrate-to-pulse-with-c-extraction-before-updating-the-stable-toolchain)
and the [trusted inventory](THREAT_MODEL.md).

`make migration-inventory-check` checks that **every** F* source/interface under
`src/` and `spec/` appears exactly once below, and that its gate agrees with the
Makefile's verification/extraction root lists. It emits direct and transitive
LowStar/HyperStack/Steel dependencies and local callers/importers in
`dist/candidate-v2026.09.13/inventory.json`. This conservative lexical scan is
not F* dependency analysis: unused imports count, and generated C/external
callers need the separate ABI review below. Adding a file or changing a build
root without updating its row fails the candidate check.

`verify+extract` means included in the stable extraction input list, **not**
necessarily linked or executable without warning debt. `verify` means the
mainline proof gate only. `everparse-verify` uses the separately pinned generator
and its own F*/Low* dependencies. Remaining “pure” modules can still depend
transitively on legacy code and must be checked after splitting those imports.

## Complete source inventory

| File | Gate | Contracts and limits to preserve | Migration disposition |
| --- | --- | --- | --- |
| `src/transport/DNS.QUIC.StreamMapping.fst` | verify+extract | `fragment_phase`, `handle_stream_data`, `handle_stream_fin`: exact prefix/body transitions, FIN and zero ID, bounds, mutation footprint; body-fragmentation lemma; caller-owned 65535-byte storage | M2: split shared pure model; Pulse context/buffer operations; first real C boundary in M3 |
| `src/transport/DNS.QUIC.Multiplexer.fst` | verify+extract | `slots_owned`, `allocate_stream`, `close_stream`: distinct/disjoint contexts, active-slot preservation and close permutation; ID/table initialization remain caller obligations | M4: Pulse table ownership; retain sequential allocation/close regressions |
| `src/transport/DNS.QUIC.MsQuicIngress.fst` | verify+extract | Authenticated fragment liveness/length, context-buffer disjointness and mutation bounds; authentication/borrow tokens are unit | M3/M4: port ingress wrapper; do not strengthen claims about trusted MsQuic |
| `src/transport/DNS.QUIC.MsQuicEgress.fst` | verify+extract | Live response buffer, length bound and send-descriptor handoff; no proof of runtime send completion | M4: Pulse buffer borrow/lifetime specification; preserve descriptor ABI |
| `src/transport/DNS.QUIC.MsQuicSendCompletion.fst` | verify+extract | Live descriptor and connection/table preconditions; cleanup delegates to close; runtime completion is trusted | M4: port cleanup under serialized ownership |
| `src/concurrency/DNS.Worker.Minimal.fst` | verify+extract | Bounds/read-write obligations for FORMERR, empty NOERROR and validated question echo; not full DNS policy | M4: Pulse response-buffer operations; retain all linked response fixtures |
| `src/concurrency/DNS.ShellBoundary.fst` | verify+extract | C-shaped ingress/FIN/worker/reset wrappers; phase code mapping and caller preconditions | M3/M4: preserve ABI or explicitly review a narrow adapter |
| `src/concurrency/DNS.ShellResponseBoundary.fst` | verify+extract | Bounded response copy, two-byte DoQ prefix, send/completion wrappers | M4: port buffer operations and send-storage ownership |
| `src/concurrency/DNS.ShellScheduler.fst` | verify+extract | Per-event liveness and mutation requirements; no scheduler/race-freedom proof | M4: preserve serialized event dispatch and C helper interfaces |
| `src/concurrency/DNS.Worker.fst` | verify | Parser/serializer-based response construction, bounded copies and send preparation; loop discards descriptor, test-zone default | M4: port buffers, reuse pure models; production extraction is separate work |
| `src/concurrency/DNS.Cache.Sharded.fst` | verify | First-shard sequential delegation; live tables; unit permission, weak wrapper postconditions and no locks | M4: preserve sequential preconditions; real sharding/concurrency remains separate |
| `src/logic/DNS.Recursive.Cache.fst` | verify | `get_from_cache` equals first-slot model with TTL aging; insertion validates authority suffix/shape, saturated expiry and mutation footprint; trusted time | M4: retain pure TTL/policy lemmas and port buffer storage to Pulse |
| `src/protocol/DNS.Protocol.Parser.fst` | verify+extract | Pure bounded parsing and contextual compression; accepted buffer packet equals parse of byte-exact snapshot; wrapper rejection can differ | M4: split reusable pure parser from Pulse buffer adapter; no new validator-equivalence claim |
| `spec/DNS.Protocol.Parser.EverParseRuntime.fsti` | verify+extract | Trusted external boolean/code API with liveness/bounds but no validator success/failure semantics | M4: replace Low* buffer interface with explicit Pulse/C boundary; keep current trust debt |
| `spec/Steel.Memory.fsti` | verify+extract | `pointer = buffer`, `vprop = unit`; trusted compatibility only, no concurrency guarantee | M4: remove after all callers migrate; never replace unit with an assumed concurrency theorem |
| `spec/Steel.ST.Util.fsti` | verify+extract | Empty compatibility import through Steel.Memory | M4: remove only after caller/import review |
| `src/security/DNS.Security.Context.fst` | verify+extract | Pure legacy crypto record and unused cipher/helper imports; no actual Steel heap protection | M4: retain pure types or retire after caller/C-symbol review |
| `src/security/DNS.Security.Gateway.fst` | verify+extract | Legacy decrypt/validate uses abstract authentication and ciphertext copy; not runtime cryptography | M4: explicitly retire unused path or port written buffer contracts; update TCB |
| `src/security/DNS.Security.Handshake.fst` | verify+extract | Abstract ClientHello validation and modeled state transition; not TLS proof | M4: retire unused path or port contracts after caller/TCB review |
| `spec/EverCrypt.AEAD.fsti` | verify+extract | Abstract authentication/decrypt declaration; no plaintext/authenticity theorem | M4: retire with gateway or retain an explicit trusted interface |
| `spec/EverCrypt.Cipher.fsti` | verify+extract | Abstract ClientHello check with bounded reads | M4: retire with handshake or retain explicit trust |
| `spec/EverCrypt.Helpers.fsti` | verify+extract | Empty import shim | M4: retire after Context/import review |
| `spec/Spec.Agile.Cipher.fsti` | verify+extract | Empty import shim | M4: retire after Context/import review |
| `src/protocol/DNS.Name.fst` | verify+extract | Wire-order/original-case labels, bounded construction, ASCII-folded equality, distinct TLD-first key conversion | Reuse pure definitions and lemmas; check current F* compatibility |
| `src/protocol/DNS.Protocol.fst` | verify+extract | DNS packet/record types and structural refinements | Reuse pure model |
| `src/protocol/DNS.Constants.fst` | verify+extract | Protocol constants | Reuse |
| `src/protocol/DNS.RCode.fst` | verify+extract | Response-code model/mappings | Reuse |
| `src/protocol/DNS.Protocol.OPT.fst` | verify+extract | EDNS structural checks, not complete EDNS semantics | Reuse pure checks |
| `src/protocol/DNS.Protocol.Serializer.fst` | verify+extract | Successful packet serialization parses back byte-exactly through reference parser; compressed opaque RDATA rejected | Reuse checked pure construction and round-trip contract |
| `src/protocol/DNS.Protocol.Parser.EverParseGenerated.fst` | verify+extract | Handwritten pure subset model; not the external generated validator | Reuse model; preserve explicit distinction from generated C |
| `src/protocol/DNS.Protocol.Parser.EverParseBoundary.fst` | verify+extract | Pure boundary/reference equivalence on modeled subset, not external runtime equivalence | Reuse lemmas after parser split |
| `src/protocol/DNS.Protocol.Parser.EverParseAdapter.fst` | everparse-verify | Links to separately generated DNSProtocol validators; availability constants are not semantic correspondence | Keep separately pinned generator; do not mix its checked files with candidate |
| `src/protocol/DNS.Protocol.Parser.Tests.fst` | verify | Pure parser/serializer/subset regression lemmas | Retain all regressions after model split |
| `src/protocol/DNS.ProofAudit.Tests.fst` | verify | Audit regressions for names, compression, serialization, stream framing and cache policy | Retain all regressions; shared model tests expand in M2 |
| `src/logic/DNS.Recursive.Security.fst` | verify | Case-folded authority suffix and answer-shape checks; incomplete resolver policy | Reuse pure model |
| `src/logic/DNS.Zone.Parser.fst` | verify | Bounded one-entry binary zone parser, not text master-file semantics | Reuse pure parser; preserve limited claim |
| `src/logic/DNS.Zone.RadixTree.fst` | verify | Authoritative lookup/response scaffolds, CNAME hop bound, partial wildcard/RRset semantics | Reuse pure logic; no new full-server claim |

## Caller and C ABI review checklist

The generated dependency report enumerates local callers for every row. These
external seams require explicit review as each replacement is integrated:

- [ ] `shell/ism_shell.c`, `ism_event_queue.c`, `msquic_adapter.c`,
  `msquic_runtime.c`, and `msquic_connection_runtime.c`: calls into
  `DNS.ShellBoundary` and `DNS.ShellResponseBoundary`, receive/FIN/reset ordering,
  exact phase codes (length prefix 0, body 1, Processing 2, Done 3, AwaitingFin 4),
  lengths, return codes, context/table field layout and integer widths.
- [ ] Stream context, active/available slots, and 65535-byte message buffer:
  alignment, live storage, disjointness, exclusive access, and ownership through
  close/reset/reuse. No mixed old/new checked or `.krml` artifacts.
- [ ] Response buffer and descriptor: two-byte prefix capacity, FIN flag,
  immutable storage until matching completion/drop, and no premature recycling.
- [ ] EverParse `DNSProtocolWrapper.c` and `EverParseRuntime` imports: use pinned
  generated C, review prototypes/lengths and ownership; do not pretend wrapper
  booleans prove parser equivalence.
- [ ] `shell/link_krml_compat_stubs.c` and legacy security symbols: generated
  prototypes, actual link users, proof callers and trusted inventory reviewed
  before retiring or changing an interface.
- [ ] M2–M4 exit evidence: source contracts preserved, audit regressions pass,
  C compile/link and applicable MsQuic smokes select the new implementation.

## Toolchain provenance and current gate scope

`migration/toolchain.lock` pins the evaluated F* Linux x86_64 bundle checksum,
compiler commit, bundled KaRaMeL commit, and bundled Z3 versions. The candidate
gate selects the bundled Z3 4.13.3 explicitly, validates tool identities, and
records C compiler/target and OS versions in `toolchain.json`. The baseline
EverParse v2026.03.21 archive and checksum are recorded separately; it continues
to run with its own compiler. Its generated C will be checked with candidate C
boundaries when those are integrated, not by this initial pilot gate.

The base image and OS packages are not digest/version locked; this is a
reproducible **proof-tool selection**, not a fully reproducible binary supply
chain. Both existing pilots verify in the required candidate job. Its C
compile/link/run gate exercises **only the pure value-state pilot**, with no
MsQuic integration, reference/buffer extraction, or semantic substitution claim.
The ref pilot's optional Rust failure is outside that job.

## M1 validation evidence (2026-09-19)

- Built `Containerfile.candidate` from the checksum-verified release archive and
  ran its default `make candidate-check` as the unprivileged container user with
  empty candidate artifact directories: both pilot proofs, all 37 inventory
  rows, C extraction and strict `-Wall -Wextra -Werror` compile/link/run passed.
  The generated C smoke covers fitting/oversized input and uint32 boundary
  arithmetic using the generated header; it does not assert DoQ semantics.
- Stable container: `make verify` and `make extract c-compile-smoke c-link-smoke`
  passed. Extraction includes the existing EverParse generation/verification
  gate. Warnings remain: ignored binders/skipped checked-cache writes, F*
  extraction warning 250 for library helpers, KaRaMeL warning 15, and C header
  macro redefinitions. This is not a warning-free baseline; no new source
  admissions or runtime interfaces were added.
- `python3 -m unittest discover -s migration/tests -v`: 15 guard tests pass,
  including wrong tool identities, inventory omissions/build-coverage drift,
  artifact routing, and one-root verification that stops at the first failure.
  Running the candidate tool check in the actual stable image also fails closed.
- Full legacy `make verify` with the candidate compiler now gets past the
  multi-file invocation issue and stops at `DNS.Name`'s missing
  `Prims.op_Addition`. Separately, the earlier direct stream probe established
  the removed HyperStack dependency. Neither failure is hidden by removing a
  root from the baseline gate; resolving them belongs to the port.
- Workflow YAML parses locally; hosted CI and branch-protection settings have
  not been executed or changed from this workspace. Latest-release/Rust checks
  remain optional; they are not evidence for M1 C-path readiness.

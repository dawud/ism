# Pulse migration contract and ABI inventory

M1 baseline: `b51de95`, reviewed 2026-09-19. This is a migration checklist, not
a claim that these modules already work on the candidate compiler. No source,
interface, or proof is retired by this inventory. M2–M4 must preserve the written
contracts, not just this summary. See [DR-0017](DECISIONS.md#dr-0017-migrate-to-pulse-with-c-extraction-before-updating-the-stable-toolchain)
and the [trusted inventory](THREAT_MODEL.md).

`make migration-inventory-check` checks that **every** F* source/interface under
`src/`, `spec/`, and `migration/` appears exactly once below, and that its gate
agrees with the Makefile's stable and candidate verification/extraction roots.
It also records candidate verification and extraction for shared stable modules.
It emits direct and transitive
LowStar/HyperStack/Steel dependencies and local callers/importers in
`dist/candidate-v2026.09.13/inventory.json`. This conservative lexical scan is
not F* dependency analysis: unused imports count, and generated C/external
callers need the separate ABI review below. Adding a file or changing a build
root without updating its row fails the candidate check.

`verify+extract` means included in the stable extraction input list, **not**
necessarily linked or executable without warning debt. `verify` means the
mainline proof gate only; `candidate-verify` denotes candidate-only proof roots;
`candidate-verify+extract` also requires candidate C extraction coverage.
`everparse-verify` uses the separately pinned generator
and its own F*/Low* dependencies. Remaining “pure” modules can still depend
transitively on legacy code and must be checked after splitting those imports.

## Complete source inventory

| File | Gate | Contracts and limits to preserve | Migration disposition |
| --- | --- | --- | --- |
| `src/transport/DNS.QUIC.StreamMapping.fst` | verify+extract | Exact shared-model transitions and byte-copy footprint, FIN and zero ID, bounds, mutation footprint; body-fragmentation lemma; caller-owned 65535-byte storage | M2 ABI-preserving bridge; retained baseline and M3 differential oracle; mixed shell uses Pulse ingress/FIN |
| `src/transport/DNS.QUIC.StreamModel.fst` | verify+extract | Heap-independent framing/FIN/ID transitions, bounded copy plan, byte-exact copy predicate, valid-phase preservation, body-fragmentation lemma | Shared by stable Low* and candidate Pulse; verified and extracted on both compilers |
| `src/transport/DNS.QUIC.StreamModel.Tests.fst` | verify | Shared framing, FIN, terminal/invalid-state, uint32 bounds and copy-plan regressions | Verified on both compilers; not extracted |
| `migration/DNS.Migration.PulseStream.fst` | candidate-verify+extract | Real reference/array ownership; exact shared-model ingress/FIN result, copied bytes and frame; input and context fields preserved | M2 proofs; M3 checked C extraction and explicit mixed-toolchain ingress/FIN lane |
| `migration/DNS.Migration.PulseStream.Tests.fst` | candidate-verify | Imperative stack-owned array/context regressions: split prefix, byte copies, FIN/ID, invalid and terminal states | M2 proof tests, not Pulse runtime/C tests |
| `migration/DNS.Migration.PulseShellBoundary.fst` | candidate-verify | Original reference-based capacity counter; no real DoQ lifecycle | Retained pilot; optional Rust assessment is separate |
| `migration/DNS.Migration.PulseShellBoundaryValue.fst` | candidate-verify+extract | Original pure value capacity counter; no real DoQ lifecycle | Retained candidate C smoke and optional Rust experiment |
| `src/transport/DNS.QUIC.Multiplexer.fst` | verify+extract | `slots_owned`, `allocate_stream`, `close_stream`: distinct/disjoint contexts, active-slot preservation and close permutation; ID/table initialization remain caller obligations | Shared permutation lemmas; retained baseline and worker-internal read-only lookups; M4 table-enabled lane replaces shell lifecycle |
| `src/transport/DNS.QUIC.TableModel.fst` | verify+extract | Abstract slot distinctness and swap membership/distinctness preservation | Shared by stable and candidate table proofs; ghost definitions erase |
| `src/transport/DNS.QUIC.TableModel.Tests.fst` | verify | Removed-slot availability, last-slot identity and duplicate rejection regressions | Stable and candidate proof tests; not extracted |
| `migration/DNS.Migration.PulseMultiplexer.fst` | candidate-verify+extract | Owned pointer table and context pool; first-match lookup, duplicate/full rejection, exact context update and close permutation; message storage framed | M4 proof/C port; table-enabled shell lifecycle via reviewed C-only snapshot ABI; adapters remain trusted |
| `migration/DNS.Migration.PulseMultiplexer.Tests.fst` | candidate-verify | Real owned-context allocate/close/reopen, failure and byte-preservation regressions | Candidate imperative proof tests; not extracted |
| `src/transport/DNS.QUIC.ResponseModel.fst` | verify+extract | Exact framed length/rejection, big-endian prefix round trip, byte-exact payload and unchanged tail | Shared stable/Pulse framing specification; checked extraction on both compilers |
| `src/transport/DNS.QUIC.ResponseModel.Tests.fst` | verify | Zero/max length, exact/short capacity, uint32 rejection and prefix byte boundaries | Stable and candidate verification-only regressions |
| `migration/DNS.Migration.PulseResponse.fst` | candidate-verify+extract | Real separated source/destination ownership; exact framing, source preservation and no writes on rejection | M4 framing proof/C port and response-enabled integration lane; descriptor/completion ownership remains open |
| `migration/DNS.Migration.PulseResponse.Tests.fst` | candidate-verify | Owned-array framing, failure, input/tail preservation, maximum length and unrelated frame regressions | Candidate imperative proof tests; not extracted |
| `src/transport/DNS.QUIC.MsQuicIngress.fst` | verify+extract | Authenticated fragment liveness/length, context-buffer disjointness and mutation bounds; authentication/borrow tokens are unit | M3 shell bypasses legacy data wrapper via reviewed C ABI; full wrapper port remains M4; no stronger MsQuic claim |
| `src/transport/DNS.QUIC.MsQuicEgress.fst` | verify+extract | Live response buffer, length bound and send-descriptor handoff; no proof of runtime send completion | M4: Pulse buffer borrow/lifetime specification; preserve descriptor ABI |
| `src/transport/DNS.QUIC.MsQuicSendCompletion.fst` | verify+extract | Live descriptor and connection/table preconditions; cleanup delegates to close; runtime completion is trusted | M4 table-enabled shell delegates cleanup to Pulse close through trusted C; descriptor/ownership proof port remains open |
| `src/concurrency/DNS.Worker.Minimal.fst` | verify+extract | Bounds/read-write obligations for FORMERR, empty NOERROR and validated question echo; not full DNS policy | M4: Pulse response-buffer operations; retain all linked response fixtures |
| `src/concurrency/DNS.ShellBoundary.fst` | verify+extract | C-shaped ingress/FIN/worker/reset wrappers; phase code mapping and caller preconditions | Public ABI retained; selected C handles ingress/FIN and M4 table cleanup; worker wrappers/internal read-only lookups still Low* |
| `src/concurrency/DNS.ShellResponseBoundary.fst` | verify+extract | Exact shared-model framing, byte-copy/tail/source/context preservation and no-write rejection; send/completion wrappers | Stable fallback and response oracle; response-enabled shell replaces framing only, retaining stable descriptor handoff; lifetime proofs remain M4 |
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

- [x] M3 stream-only C seam: both shell data entry points and FIN select Pulse;
  explicit phase conversions, unchanged shell context layout/identity, fixed
  message capacity, separated synchronous input ownership and no retained
  pointers. See [PULSE_C_ABI.md](PULSE_C_ABI.md). Broader M4 seams below remain open.
- [x] M4 shell table seam: bounded snapshot/permutation mapping, idempotent open,
  reset/completion close and immediate flag synchronization; no generated context
  casts or moved buffers. See [PULSE_TABLE_C_ABI.md](PULSE_TABLE_C_ABI.md). The C
  adapters are trusted; this is not a full response-lifetime/ownership proof.
- [x] M4 synchronous response framing seam: neutral byte pointers/capacities,
  source/destination/context separation, no retained pointer, exact byte/rejection
  comparisons and stable descriptor/FIN handoff retained. See
  [PULSE_RESPONSE_C_ABI.md](PULSE_RESPONSE_C_ABI.md). Asynchronous storage ownership
  below remains open; two C adapters are explicitly trusted.
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
to run with its own compiler. Its generated C is linked into the mixed integration
gate, not the standalone candidate stream/value smoke tests.

The base image and OS packages are not digest/version locked; this is a
reproducible **proof-tool selection**, not a fully reproducible binary supply
chain. The shared models, real Pulse stream/table/response implementations and
their regressions, as well as both existing pilots, verify in the required
candidate job. Its C compile/link/run gates exercise the real reference/array
stream implementation and the original value-state pilot separately, plus the
M4 table and response framing ports/ABIs.
The stable CI job runs `pulse-integration-check`, `pulse-table-integration-check`
and `pulse-response-integration-check`: only checked C archives cross toolchains.
They successively select ingress/FIN, shell find/open/reset/completion table
lifecycle, then response framing. Default and older lanes retain stable framing.
Runtime assumptions depend on the stream, table and response C adapters,
all reviewed/tested but unverified. The ref pilot's optional Rust failure is
outside these jobs; whole-project candidate compatibility remains M4/M5.

## M4 response framing contract correspondence

DR-0023 establishes shared response framing proofs; DR-0024 extracts and selects
that framing in a separate runtime lane. Neither replaces the descriptor/
completion ownership proofs or the runtime's asynchronous lifetime obligations.

| Obligation | Stable boundary | Pulse response port |
| --- | --- | --- |
| Input ownership | Live buffers, bounded source length and destination capacity; destination disjoint from source/context | Separate fully owned source/destination arrays with bounded length/capacity; compatible resources may be framed |
| Success | `prepare_doq_response_send_for_stream` satisfies shared `framing_result`; exact big-endian prefix and payload, unchanged input/context/tail | `frame_response` satisfies the same byte-level result and preserves source ownership/content |
| Rejection | Length above 65535 or capacity below length + 2 returns zero with no heap mutation | Same result, both arrays unchanged; bound checked before addition |
| Empty response | Returns two with a zero prefix when capacity permits | Identical; neither contract validates DNS response semantics |
| Copy helper aliasing | Existing helper preconditions retained; new snapshot-copy/source-preservation facts apply only when disjoint | Copy primitive requires separated array ownership; no aliased-call equivalence claimed |
| Egress/completion | Existing context/FIN/descriptor and cleanup code retained | No descriptor or asynchronous borrow/completion API yet; framing is synchronous only |
| Extraction/runtime | Shared helpers extracted with the stable response wrapper; default and earlier mixed lanes retain it | Checked response archive and C-only adapters select framing in the response-enabled lane; stable descriptor handoff retained |

`lemma_prefix_roundtrip` relates the emitted prefix to the shared ingress
decoder for every representable protocol length; it does not prove a full
send/receive lifecycle. Pure regressions include uint32 maximum rejection;
imperative tests cover short capacity, empty/maximum payloads, exact copies,
unchanged input/tail and an unrelated owned reference. Large array fixtures take
`SizeT` values refined to their real sizes: this avoids assuming wider-than-16-bit
`SizeT` support and makes those fixtures conditional on representable sizes.
The proof slice adds no admission or platform axiom. DR-0024 adds two unverified
C adapters with explicit caller obligations, range checks, artifact/selection
guards and differential tests; see [response ABI review](PULSE_RESPONSE_C_ABI.md).
Source and destination must remain live and exclusively owned for the call;
immutable response storage until completion remains a separate runtime/proof
obligation. Array proofs do not prove that raw C callers establish ownership.

## M4 table contract correspondence

`DNS.QUIC.TableModel` supplies distinctness, swap preservation and membership
lemmas checked by both compilers. The stable multiplexer delegates its existing
distinctness lemma to this model without changing executable behavior or public
types. `DNS.Migration.PulseMultiplexer` implements actual reference/pointer-array
lookup, slot reservation (called allocation) and close, not a value-only pilot.

| Operation | Candidate postcondition and preserved behavior | Difference / remaining obligation |
| --- | --- | --- |
| Lookup | First matching active index; count sentinel iff absent; all storage unchanged | Legacy returns an option pointer; caller must map a successful index to its context |
| Allocation | Capacity sentinel iff duplicate ID or full; rejection changes nothing; success uses the old-count slot, changes only its ID/phase to `ReadingLength`, retains its buffer, increments count, preserves all other contexts | No memory allocator; preallocated slots and their storage remain caller-owned |
| Close | First matching slot swapped with last active slot, count decremented, all context values unchanged; miss changes nothing; distinctness and membership preserved | Returns bool; legacy wrapper returns unit; removed slot remains available rather than freed |
| Ownership | Separate connection reference, pointer array and distinct pool context references; fixed ghost pool independent of mutable ordering; exact snapshot preservation | Uniform full ownership, including an empty active prefix, is stronger than legacy lookup/close's conditional liveness requirements |
| Message storage | Buffer identity preserved; arbitrary compatible message resources are framed and untouched | Table predicates alone do not establish buffer liveness, 65535-byte capacity or separation needed for ingress |

The pool is a ghost finite sequence with a snapshot mapping each reference to
its value, not a runtime allocation or side table. Recursive take/restore
proofs transfer a single reference resource and reassemble the pool; finite
ghost search obtains its index without a new choice or ownership axiom. Lookup
has a decreasing variant on both hit and miss. Bounds prevent count overflow
and close underflow; executable indices use the checked UInt32-to-SizeT cast.
Duplicate IDs on distinct context pointers are permitted on input; lookup and
close choose the first one, while allocation rejects another copy.

Correspondence here is a reviewed mapping of written contracts on the common
owned-table domain, not a cross-heap bisimulation theorem or proof of arbitrary
raw C callers. Candidate tests compose real imperative operations with owned
stack references/arrays and check allocate, reject, close, reuse, unchanged
other contexts and message bytes. The C oracle uses integer slot identities
and checks generated pointer operations independently over permutations and
mutation sequences. Neither fixture testing nor successful C extraction proves
ABI compatibility or runtime ownership establishment.

`candidate-multiplexer-verify` and `candidate-multiplexer-c-smoke` are required
by `candidate-check`. All four new source roots are inventoried; shared test
lemmas remain verification-only in both lanes. Checked extraction retains
cross-module inlining and the bundled Pervasives helper, rejects F* warning 250
and KaRaMeL warnings 2/4/15, and writes only into the lane's
`pulse-multiplexer/` directory. The generated C contains native pointer/index
operations; ghost pool/snapshot arguments erase (an unused snapshot typedef
may remain in the header), with no heap allocator or replacement runtime shim.

DR-0021's first slice added no C adapter. DR-0022 subsequently integrates the port
through two reviewed, unverified table adapters in the separate table-enabled
lane. They materialize local candidate contexts and map operations back to stable
physical slot identities; no generated context casts or message moves are used.
See [PULSE_TABLE_C_ABI.md](PULSE_TABLE_C_ABI.md) for exact caller obligations and
limits. The original M3 mixed gate retains the stable table. Egress/completion
ownership, remaining worker/shell/parser/cache/security surfaces (including
worker-internal read-only table lookups) and M5 remain open.

## M2 contract correspondence

`DNS.QUIC.StreamModel` has no Low*/HyperStack/Steel dependency. The stable
`StreamMapping` retains its public datatype and uses total, round-trip-proved
conversions to the shared model. Its original phase, context, liveness and
mutation postconditions remain, with a new byte-exact copying postcondition.
The model deliberately has a different constructor order: pinned KaRaMeL merges
enum tag types with identical constructor-name lists, otherwise replacing the
stable public `StreamMapping_*` names. The C audit smoke guards all six stable
constructor tags and their one-byte type. Never cast between the two phase
representations; constructor tags also differ from the shell's 0–4 phase codes.
The Pulse implementation uses that same transition and copy-plan code, with
real `Reference.pts_to` and `Array.pts_to` resources. Its loop proves every
copied byte equals the input slice and all other message bytes remain unchanged.
It preserves the input, stream ID and message-array identity; FIN leaves all
message bytes unchanged. No allocation/free or ownership assumptions are added.

Valid phases have body lengths 12–65535, strictly incomplete `ReadingMessage`
counts, or are prefix/terminal phases. Shared universal lemmas preserve validity
from valid input, establish terminal `Done`, and retain body-fragmentation
equivalence. Stable bridge lemmas and the Pulse postconditions establish model
correspondence for all typed states, not just the regression examples. This
does **not** add sanitization of all invalid states: historically representable
`AwaitingFin 0` is still processed by zero-ID FIN. Raw invalid C phase codes
and ownership establishment by C callers are covered by the M3 adapter review
and its explicit trusted caller requirements, not an F* proof of the C adapters.

Pulse requires separate, fully owned context, message and input storage;
read-only shared input borrowing is not implemented. The stable disjointness
and serialization obligations remain. Rejected fragments may still copy a
bounded body prefix before becoming `Done`, exactly as in the original code.
Candidate proof tests call real imperative operations using stack-owned arrays
and references. These proofs do not establish C integration by themselves; M3
adds the separate extraction/ABI/runtime gates below. Neither milestone proves
full-stream fragmentation equivalence, authentication, whole-runtime race
freedom or full DNS semantics. M4/M5 remain open.

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

## M2 validation evidence (2026-09-20)

- Pinned candidate container: `make candidate-check
  CANDIDATE_LANE=candidate-v2026.09.13-m2-final` passed using fresh lane output
  directories. All six roots verified: shared model and regressions, real
  Pulse stream implementation and imperative regressions, and the two original
  pilots. The 43-row inventory and strict value-only C compile/link/run passed.
  Provenance and inventory are under that lane's `dist/` directory.
- Pulse regressions exercise split prefixes and actual copied bytes, fragmented
  body/excess-byte bounds, unchanged input and unrelated framed storage, FIN,
  repeated FIN, zero/nonzero ID, and terminal/invalid body states. The shared
  pure regressions additionally cover minimum/maximum lengths and uint32
  overflow rejection. These are proof-checked tests, not extracted Pulse tests.
- `python3 -m unittest discover -s migration/tests -v`: all 20 guard tests pass,
  including candidate source omission, build-root coverage, lane isolation and
  required stream tests. Workflow YAML parses locally; hosted CI was not run.
- The first stable C link run exposed cross-module enum-tag deduplication.
  The shared constructor order and explicit conversions now keep its tags
  distinct from the stable ABI; the C audit smoke checks all stable tag names,
  values and width. No C adapter, shell behavior or stable tool pin was changed.
- After that fix, the stable container passed full `make verify` (also required
  by `make extract`), EverParse generation/verification, `make extract`,
  `c-compile-smoke`, `c-link-smoke`, and every `msquic-runtime-*-smoke`: compile,
  link, lifecycle, listener, connection callbacks and live loopback stream.
  These exercise the stable Low* implementation using the shared model, not
  the Pulse port. The public `DNS_ShellBoundary.h`, `DNS_ShellResponseBoundary.h`
  and `DNS_Protocol.h` contents match the pre-refactor generated headers exactly
  after excluding their generation banners.
- Existing warning debt remains: ignored binders/checked-cache writes, F*
  library extraction warning 250, KaRaMeL GC/list warning 15, and redefined
  `KRML_CHECK_SIZE`. No new source admissions or unverified adapters were added;
  passing these gates does not close the remaining trusted boundaries.

## M3 validation evidence (2026-09-22)

- Pinned candidate container: `make candidate-check
  CANDIDATE_LANE=candidate-v2026.09.13-m3-final` passed with fresh candidate
  directories. All six proof roots and the 43-row verification/extraction
  inventory pass. Both value-pilot and real reference/array stream C gates pass.
  Source/product hashes, bundle identities and C target are recorded in that
  lane's `pulse-stream/stream-manifest.json` alongside the generated C/archive.
- Real-port C review found only native pointers/integers, bounded copy loops
  and local context updates: ghost ownership/validity proofs erase, and no heap
  allocator, GC or missing Pulse runtime primitive is linked. Checked extraction
  succeeds with cross-module inlining and the bundled Pervasives helper; the
  executable SizeT casts retain the same proved bounds. No new proof admissions
  or assumptions were introduced. An ignored-binder warning remains; strict
  real-port extraction/KaRaMeL and C warning gates pass.
- Stable container passed `make verify extract c-compile-smoke c-link-smoke`
  and all six `msquic-runtime-*-smoke` gates with the default Low* implementation.
  `make pulse-integration-check` then passed both in the default mixed lane and
  against the fresh `candidate-v2026.09.13-m3-final` archive, with integration
  outputs set to `dist/pulse-integration-v2026.09.13-m3-final` and the matching
  `obj/` directory. This includes stable verification, EverParse generation/
  verification and extraction, archive checks, strict adapter compilation,
  actual shell-object selection checks, all C/audit and MsQuic gates, callback
  tests and live loopback with Pulse ingress/FIN selected.
- The differential executable passes 1071 combinations of typed states,
  fragment lengths/prefixes and FIN ID bytes, comparing phase/result and all
  65535 message bytes, including preserved historical invalid-state behavior.
  Raw unrepresentable states are tested only against the rejecting adapter,
  not invoked outside the old implementation's contract. Standalone C tests
  additionally exercise all minimal-message splits, capacity/alias failures,
  maximum message size, unchanged input and guard bytes.
- The standalone extracted C plus candidate marshaler passes native Clang
  AddressSanitizer/UndefinedBehaviorSanitizer tests. The initial GCC sanitizer
  link could not find the host runtime libraries; Clang's installed runtimes
  supplied this supplemental check. It is not a sanitizer run of the full server.
- All 34 migration guard tests pass, including wrong ABI/pins/target, changed
  source/archive, incomplete manifests, unexpected archive/runtime dependencies
  and missing Pulse/retained legacy ingress selection. Workflow YAML parses and
  `git diff --check` passes. Hosted CI and branch protection were not run/changed.
- Stable public `DNS_ShellBoundary.h`, `DNS_ShellResponseBoundary.h` and
  `DNS_Protocol.h` bodies remain identical to the pre-refactor ABI (excluding
  generation banners). Stable extraction warning 250, KaRaMeL GC/list warning
  15 and `KRML_CHECK_SIZE` redefinition debt remain; no whole-build warning-free
  claim is made. The two new C marshalers are explicitly recorded in the
  [trusted inventory](THREAT_MODEL.md) and [ABI contract](PULSE_C_ABI.md).
  Stable defaults/pins remain unchanged; M4/M5 are not closed.

## M4 first table slice validation evidence (2026-10-01)

- Pinned candidate container: `make candidate-check
  CANDIDATE_LANE=candidate-v2026.09.13-m4-final` passed, initially with fresh lane
  output directories and again after final build-guard edits. All ten proof
  roots and the 47-file inventory pass. Required C gates cover the original
  value pilot, real stream ingress/FIN and standalone table port separately.
- Table proof regressions compose lookup, empty/missing close, successful and
  rejected allocation, first/last close, slot reuse and preservation of other
  contexts and framed message bytes. The sequence test uses explicit SMT fuel
  (`--z3rlimit 100`); it adds no admission or assumption. Shared permutation
  regressions also verify in the stable lane.
- Strict table C compilation/link/run passed 15,520 state/byte comparisons
  covering all four-slot permutations, capacities 0–4, all active prefix
  lengths, duplicate and distinct IDs, missing IDs, first-match behavior and
  chained close/reopen operations. Every check includes the whole pointer
  table, context fields and all four 65535-byte message buffers. Native Clang
  AddressSanitizer/UndefinedBehaviorSanitizer also passed the same tests; this
  is supplemental table-only evidence, not a sanitizer run of the full server.
- Generated table C review found bounded native loops/indexing, context updates
  and pointer swaps; pool/snapshot/ownership proofs erase. No allocation, GC,
  assumed Pulse runtime primitive or new unverified adapter is introduced.
- Stable container: full `make verify`, `make extract` (including EverParse),
  both C smoke gates and all six `msquic-runtime-*-smoke` targets passed. Public
  `DNS_ShellBoundary.h`, `DNS_ShellResponseBoundary.h` and `DNS_Protocol.h` bodies
  match the M3 baseline hashes after excluding generation banners. Existing
  F* extraction warning 250, KaRaMeL warning 15 and C macro redefinition debt
  remain; this is not a warning-free whole-project build.
- Stable-image `make pulse-integration-check
  CANDIDATE_LANE=candidate-v2026.09.13-m4-final` passed against the final archive:
  manifest/selection checks, 1071 ingress/FIN differential comparisons, C smoke
  gates and every MsQuic gate including live loopback. This still selects only
  Pulse ingress/FIN with the stable table; it is not table integration evidence.
- All 36 migration guard tests pass, including new required table proof/C gate
  and verification-only regression coverage checks. Workflow YAML parses and
  `git diff --check` passes; hosted CI and branch protection were not run/changed.

## M4 table integration validation evidence (2026-10-01)

- Pinned candidate `make candidate-check
  CANDIDATE_LANE=candidate-v2026.09.13-table-integration` passed from a fresh lane
  and again after the final ABI/provenance edits. All ten proof roots, the 47-file
  inventory, existing pilot/stream gates, 15,520 direct table comparisons and new
  neutral table ABI tests pass. Both checked archives and manifests are recorded
  under that lane; no F* contract, proof root or tool pin changes in this slice.
- Stable container passed `make verify extract`, both C smoke targets and all six
  MsQuic targets with defaults, then `pulse-integration-check` and
  `pulse-table-integration-check` against those archives. Both mixed lanes pass
  the 1071 ingress/FIN differential comparisons and all C/MsQuic smokes, including
  callback and live loopback tests. Table selection is checked on the exact
  compiled shell/adapter objects used by the table-enabled runtime gates.
- The table-enabled lane passed 32,832 comparisons against the independently
  compiled baseline shell: every four-slot permutation/capacity/prefix, distinct
  and duplicate IDs, lookup/idempotent open, reset, both direct and dispatched
  completion outcomes, chained reuse and complete ingress/FIN/close sequences.
  Comparisons include physical pointer identity, all fields/permutation/flags
  and all message bytes. Invalid descriptors are separately rejected without
  writeback; the baseline is not invoked outside its contract.
- New neutral-ABI tests check null/wrapped/undersized/aliased message descriptors,
  bad permutations/counts/operations/phases, all representable phase tags and
  exact no-write failure behavior. They also pass native Clang AddressSanitizer
  and UndefinedBehaviorSanitizer. This is adapter/table-only sanitizer evidence,
  not a sanitizer run of the whole server.
- All 42 migration guard tests pass, including table manifest source/product
  drift, wrong target, archive/shim checks and missing Pulse/retained legacy
  cleanup selection. Workflow YAML parses and `git diff --check` passes; hosted
  CI and branch protection were not run/changed. The three public stable header
  body hashes remain unchanged. Existing stable warning 250/15 and C macro
  redefinition debt remain; strict new candidate/adapter C compilation passes.
- Two new table adapters and selected cleanup dispatch are explicitly recorded
  in the trusted inventory and table ABI review. No ownership theorem for raw C
  or new completion-lifetime proof is claimed. Default and M3-only behavior/pins
  remain available; the remaining M4 surfaces and M5 promotion are still open.

## M4 response framing proof validation evidence (2026-10-02)

- Pinned candidate `make candidate-check
  CANDIDATE_LANE=candidate-v2026.09.13-response-proof` passed from a fresh lane:
  51 inventoried files, 14 candidate proof roots, and all existing pilot/stream/
  table C gates. Response model/implementation/tests are explicitly candidate
  proof-only, not extracted or runtime-selected. The table gate still passes
  15,520 direct comparisons and neutral ABI checks.
- Shared proof regressions cover empty/max protocol length, short/exact capacity,
  prefix byte boundaries and uint32 overflow rejection. Real Pulse array tests
  check source/tail preservation, no-write rejection and an unrelated owned
  reference. Maximum-size fixtures use actual representable `SizeT` arguments,
  not a new target-width assumption. The universal framing and prefix round-trip
  contracts verify without new admissions or additional SMT resource overrides.
- Stable `make verify extract`, both C smoke gates and all six
  `msquic-runtime-*-smoke` targets passed, including EverParse verification and
  live loopback. The strengthened stable framing wrapper retains every original
  precondition. Its C smoke now checks 120 combinations of payload length,
  capacity and FIN code, comparing all source/output bytes, guards and context
  fields, including 65535-byte success and 65536-byte rejection. These are
  stable generated-C tests, not tests of extracted Pulse response code.
- Stable-image `pulse-integration-check` and `pulse-table-integration-check`
  passed against the new lane's checked archives/manifests. Both passed 1071
  stream differential comparisons and every C/MsQuic gate; the table-enabled
  lane also passed 32,832 baseline shell comparisons. Both retain stable response
  framing. No new runtime selection macro, archive or adapter is introduced.
- Public `DNS_ShellBoundary.h`, `DNS_ShellResponseBoundary.h` and `DNS_Protocol.h`
  body hashes are unchanged (generation banners excluded). C review confirms
  the shared rejection/shift/cast helpers and erased proof snapshots; existing
  recursive stable copying and descriptor construction remain. New helper
  declarations are internal to the stable bundle. Existing stable extraction
  warning 250/15 and C macro redefinition debt remain.
- All 44 migration guard tests pass, including required response proof roots,
  isolated caches, stable model extraction and verification-only candidate
  response coverage. Workflow YAML parses and `git diff --check` passes. Hosted
  CI/branch protection were not run or changed. DR-0023 and the trusted inventory
  distinguish synchronous framing from the still-open descriptor/completion
  lifetime proof; M4/M5 and stable toolchain promotion remain open.

## M4 response framing C integration evidence (2026-10-02)

- Pinned candidate `make candidate-check
  CANDIDATE_LANE=candidate-v2026.09.13-response-integration` passed from a fresh
  lane and again after the final gate edits. All 51 inventoried files, 14 proof
  roots and existing pilot/stream/table C gates remain covered. Shared response
  semantics and `PulseResponse` now have checked C extraction coverage; proof
  tests remain verification-only. All three archives have current manifests.
- Strict response C compilation and direct/neutral-ABI smoke passed 240 complete
  byte comparisons: empty, byte-boundary, near-maximum and maximum payloads,
  short/exact/extra capacity and multiple input patterns. Descriptor checks cover
  null/nonempty input, length/capacity mismatch, overlapping and wrapped address
  ranges, valid adjacent slices and a null empty source. Invalid descriptors are
  never passed directly to generated code outside its verified preconditions.
- Native Clang AddressSanitizer/UndefinedBehaviorSanitizer passed the generated
  response code and candidate adapter tests. The first run encountered the
  sandbox tracing restriction on LeakSanitizer; the same binary passed outside
  the sandbox. This is response/neutral-adapter evidence, not a sanitizer run of
  the stable adapter, mixed runtime or full server.
- Generated C review confirms bound-before-addition rejection, correct shift/
  truncation, a bounded native copy loop, erased proofs and no allocation or
  assumed Pulse runtime shim. The response archive has exactly the generated
  object and neutral adapter, with only the expected generated framing symbol
  as an unresolved cross-object dependency. No new F* precondition or admission.
- Stable `make verify extract`, EverParse, both C smoke gates and all six MsQuic
  gates passed. Public stable shell, response and protocol header body hashes
  remain identical, excluding generation banners. Existing stable extraction
  warning 250/15 and C macro redefinition debt remain.
- Stable-image `pulse-integration-check`, `pulse-table-integration-check` and
  `pulse-response-integration-check` passed against the candidate archives.
  The response lane passed 1,440 comparisons against independently compiled
  baseline shell code: all six phases, zero/max/missing IDs, both FIN values,
  empty/max/oversized payloads and short/exact capacities, all source/output
  bytes, guards and complete connection preservation. Invalid descriptor and
  context-overlap rejection is tested only on the new adapter, not outside the
  baseline's preconditions. Every mixed lane passes 1071 stream comparisons;
  table/response lanes also pass 32,832 table comparisons and all C/MsQuic gates,
  including real callback/live-loopback response submission and completion.
- The required isolated handoff smoke passes against the actual adapter and
  extracted archive: exact context/pointer/framed length, FIN codes 0/1/255,
  empty/nonempty success and no handoff on rejection. Its test-only descriptor
  observer is never linked into the real differential or MsQuic gates.
- All 51 migration guard tests pass, including strict response extraction,
  separate older lanes, manifest source/product drift and ABI/target/pin checks,
  archive/runtime-shim rejection and actual Pulse selection with the stable
  descriptor handoff retained. Workflow YAML parses and `git diff --check`
  passes; hosted CI and branch protection were not run/changed. DR-0024 and the
  trusted inventory record the two new C adapters and the still-open descriptor/
  completion ownership proof. Stable defaults/pins are unchanged; M4/M5 remain open.

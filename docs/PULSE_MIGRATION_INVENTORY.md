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
| `src/transport/DNS.QUIC.Multiplexer.fst` | verify+extract | `slots_owned`, `allocate_stream`, `close_stream`: distinct/disjoint contexts, active-slot preservation and close permutation; ID/table initialization remain caller obligations | M4 first slice shares permutation lemmas with the candidate port; stable/runtime implementation retained |
| `src/transport/DNS.QUIC.TableModel.fst` | verify+extract | Abstract slot distinctness and swap membership/distinctness preservation | Shared by stable and candidate table proofs; ghost definitions erase |
| `src/transport/DNS.QUIC.TableModel.Tests.fst` | verify | Removed-slot availability, last-slot identity and duplicate rejection regressions | Stable and candidate proof tests; not extracted |
| `migration/DNS.Migration.PulseMultiplexer.fst` | candidate-verify+extract | Owned pointer table and context pool; first-match lookup, duplicate/full rejection, exact context update and close permutation; message storage framed | M4 first slice: candidate proof and standalone C port; mixed-shell table substitution remains open |
| `migration/DNS.Migration.PulseMultiplexer.Tests.fst` | candidate-verify | Real owned-context allocate/close/reopen, failure and byte-preservation regressions | Candidate imperative proof tests; not extracted |
| `src/transport/DNS.QUIC.MsQuicIngress.fst` | verify+extract | Authenticated fragment liveness/length, context-buffer disjointness and mutation bounds; authentication/borrow tokens are unit | M3 shell bypasses legacy data wrapper via reviewed C ABI; full wrapper port remains M4; no stronger MsQuic claim |
| `src/transport/DNS.QUIC.MsQuicEgress.fst` | verify+extract | Live response buffer, length bound and send-descriptor handoff; no proof of runtime send completion | M4: Pulse buffer borrow/lifetime specification; preserve descriptor ABI |
| `src/transport/DNS.QUIC.MsQuicSendCompletion.fst` | verify+extract | Live descriptor and connection/table preconditions; cleanup delegates to close; runtime completion is trusted | M4: port cleanup under serialized ownership |
| `src/concurrency/DNS.Worker.Minimal.fst` | verify+extract | Bounds/read-write obligations for FORMERR, empty NOERROR and validated question echo; not full DNS policy | M4: Pulse response-buffer operations; retain all linked response fixtures |
| `src/concurrency/DNS.ShellBoundary.fst` | verify+extract | C-shaped ingress/FIN/worker/reset wrappers; phase code mapping and caller preconditions | M3 preserves public ABI; selected C adapter handles ingress/FIN; remaining operations stay Low* until M4 |
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

- [x] M3 stream-only C seam: both shell data entry points and FIN select Pulse;
  explicit phase conversions, unchanged shell context layout/identity, fixed
  message capacity, separated synchronous input ownership and no retained
  pointers. See [PULSE_C_ABI.md](PULSE_C_ABI.md). Broader M4 seams below remain open.
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
chain. The shared models, real Pulse stream/table implementations and their regressions,
as well as both existing pilots, verify in the required candidate job. Its C
compile/link/run gates exercise the real reference/array stream implementation
and the original value-state pilot separately, plus the standalone M4 table.
The stable CI job additionally
runs `pulse-integration-check`: only the checked C archive crosses toolchains,
and actual shell receive/FIN selects Pulse. Runtime assumptions still depend on
two reviewed, unverified marshalers. The ref pilot's optional Rust failure is
outside these jobs; whole-project candidate compatibility remains M4/M5.

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

No new C adapter or runtime table selection is added. The existing mixed gate
continues to exercise the stable table with Pulse ingress/FIN only. A neutral
table ABI and explicit caller initialization/lifetime/serialized ownership
review are the next M4 work; do not cast stable contexts to candidate generated
types. Egress/completion, remaining worker/shell/parser/cache/security surfaces
and M5 promotion remain open. See DR-0021.

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

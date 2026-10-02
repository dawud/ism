# Project Decision Records

This document records durable architectural and process decisions for the
verified DNS-over-QUIC server. Consult it before changing architecture,
toolchain policy, parser strategy, verification gates, or trusted boundaries.

## DR-0001: Use a Defensive-Ring Architecture

**Status:** Accepted

**Context:** The server handles untrusted network input and needs a clear
boundary between unverified I/O code and verified protocol logic.

**Decision:** Structure the server as defensive layers: an unverified C shell
for sockets and scheduling, an EverCrypt security gateway, an EverParse parser
gatekeeper, verified F* core logic, and Steel-managed concurrent memory.

**Consequences:** Data must cross explicit validation and authentication
boundaries before reaching core logic. Trusted shell and adapter boundaries must
remain visible in the threat model.

## DR-0002: Track Roadmap Maturity Explicitly

**Status:** Accepted

**Context:** F* models can verify while still relying on `admit()`, `assume`,
local mocks, placeholders, or incomplete executable behavior.

**Decision:** Track maturity as `Modeled`, `Verified scaffold`, `Implemented
with caveats`, `Extracted`, `Integrated`, and `Production-ready`.

**Consequences:** A verified module is not automatically production-ready.
Roadmap updates must distinguish proof success from extraction, integration,
and trusted-boundary closure.

## DR-0003: Define Phase Completion Gates

**Status:** Accepted

**Context:** Phase labels can overstate maturity unless completion criteria are
explicit.

**Decision:** A phase is complete only when no phase-critical `admit()` or
`assume` remains, trusted dependencies are documented, containerized
verification succeeds, extraction succeeds or non-extractable code is marked
specification-only, representative tests exist, and the RFC compliance matrix is
updated.

**Consequences:** Partial implementations remain marked with caveats until
proof debt, extraction, tests, and documentation are aligned.

## DR-0004: Use the Project Everest Stack

**Status:** Accepted

**Amendment:** DR-0017 selects Pulse as the planned imperative/proof target
while retaining KaRaMeL C extraction; the Low* stable lane remains until promotion.

**Context:** The project needs high-assurance parsing, concurrency,
extraction, compilation, and a clear boundary for transport security.

**Decision:** Use F*/Low* for verified implementation, EverParse for parser
generation, HACL*/EverCrypt where directly integrated, Steel for concurrency
proofs, KaRaMeL for C extraction, and CompCert as the intended high-assurance C
compiler. QUIC/TLS ownership is recorded separately in DR-0011.

**Consequences:** Local mocks under `spec/` are temporary bootstrap shims. The
implementation must eventually use real Project Everest / Low* / Steel
interfaces or document narrow trusted adapters.

## DR-0005: Treat the Handwritten Parser as the Bootstrap Reference

**Status:** Accepted

**Context:** The repository currently has a handwritten F*/Low* DNS parser with
tests and a verified Low* buffer boundary, but EverParse remains the production
parser target.

**Decision:** Use `DNS.Protocol.Parser` as the bootstrap/reference parser for
closing DNS semantics, developing tests, and validating the Low* buffer
boundary. EverParse remains the long-term production parser/serializer target.
Before Phase 1 is production-ready, the project must either replace the
handwritten parser with an EverParse-generated parser or prove/document
behavioral equivalence.

**Consequences:** The handwritten parser must not silently become a permanent
second parser architecture. Parser tests should be reusable against the
generated parser or equivalence layer.

## DR-0006: Use Verification and Extraction as Separate Gates

**Status:** Accepted

**Context:** F* verification and KaRaMeL extraction answer different questions:
whether obligations verify, and whether verified code can be emitted as C.

**Decision:** Run `make verify` as the verification gate and `make extract` as a
separate extraction gate. CI should run containerized verification on every
change and add extraction once blockers are isolated or resolved.

**Consequences:** A verification pass with `admit()`, `assume`, or mocks is
acceptable for scaffolding only when the corresponding proof debt stays visible
in `docs/TODO.md` and the threat model.

## DR-0007: Treat Current Extraction as a Smoke Test

**Status:** Accepted

**Context:** Containerized `make extract` completes and emits C/H files under
`dist/`, `make c-compile-smoke` syntax-checks the generated artifacts, and
`make c-link-smoke` links and runs a tiny generated-boundary harness covering
the protocol/EverParse parser boundary, `DNS.ShellBoundary` ingress and minimal
worker error-response ABIs, C-shaped scheduler helper ABIs for ingress,
minimal worker error-response, and send completion, and
`DNS.ShellResponseBoundary` response send handoff/completion ABI, plus the
fixed-capacity C shell scaffold over those generated boundaries.
KaRaMeL still reports warning-15 diagnostics for GC-backed lists,
mathematical integers, and specification-oriented definitions. Response-handoff,
scheduler send-completion, minimal worker error-response construction,
shell/scheduler minimal-worker dispatch, and stream lookup/close use
machine-integer-friendly code, but stream accumulation and the protocol model
still carry warning debt. The current extraction gate verifies all scaffold
modules but only emits a clean parser, authenticated-ingress, minimal 12-byte
FORMERR worker error-response construction, response send handoff/completion,
C-shaped scheduler helper, and fixed-capacity shell-scaffold link surface.

**Decision:** Treat current extraction as a generated-artifact smoke test, not
proof that generated output is production C. Classify warning-15 debt as
specification-only code, executable code needing Low* rewrites, compatibility
header use, or generated/trusted adapter boundary work.

**Consequences:** Extraction warning debt must be reduced or explicitly
classified before extraction becomes a production gate. Full worker
response-construction and the rich `DNS.ShellScheduler.dispatch_shell_event`
union remain verification-only follow-up work until those paths are rewritten or
emitted in a stable shell-facing form without pulling non-Low* globals into the
linked C surface.

## DR-0008: Pin the Stable F* Lane to v2026.03.24

**Status:** Accepted

**Context:** F* `v2026.04.17` removed the old Low* sublanguage, while this
repository still depends on legacy Low*/KaRaMeL compatibility.

**Decision:** Keep the stable development lane pinned to F* `v2026.03.24` while
old Low* APIs remain in use. Track newer F* releases in a non-blocking migration
lane.

**Consequences:** Upgrading the stable lane is a migration project, not routine
dependency refresh. Promotion requires verification, extraction strategy, mock
and trusted-adapter review, threat-model updates, and parser-strategy alignment.

## DR-0009: Keep Parser Tests Executable Across Boundaries

**Status:** Accepted

**Context:** Parser tests are needed while extraction and EverParse integration
are still in progress.

**Decision:** Keep executable parser tests for valid packets, malformed
headers/QNAMEs, invalid labels, trailing bytes, nonzero RR-section counts,
unknown QTYPEs, and rejected compression pointers. These tests should
eventually run against both the pure parser and the Low* buffer boundary.

**Consequences:** Parser behavior changes should update the shared tests first,
then the pure parser, Low* boundary, and generated-parser path as applicable.

## DR-0010: Maintain the RFC Compliance Matrix

**Status:** Accepted

**Context:** DNS-over-QUIC spans multiple RFCs, and partial implementation can
make compliance unclear.

**Decision:** Maintain the RFC compliance matrix in `docs/PLAN.md` as parser,
transport, EDNS0, TLS, and related protocol work changes status.

**Consequences:** Protocol changes must update implementation, tests/proofs,
and the matrix together when compliance status changes.

## DR-0011: Delegate QUIC/TLS to the Unverified Shell

**Status:** Accepted

**Context:** The public miTLS and EverQuic artifacts are research-oriented and
not a maintained drop-in production QUIC/TLS stack for this repository. Using
`everquic-crypto` alone would only cover QUIC packet/header protection, not TLS
handshake policy, QUIC transport state, recovery, flow control, stream
scheduling, socket I/O, or event-loop integration.

**Decision:** Delegate TLS 1.3, QUIC transport, packet protection, recovery,
flow control, key updates, connection lifecycle, and socket/event-loop behavior
to the unverified shell using a well-maintained QUIC/TLS implementation. The
verified core owns DNS parsing, DoQ stream-message framing above authenticated
QUIC streams, request handling, response construction, cache/zone logic, and
resource invariants at the shell/core boundary.

**Consequences:** TLS authenticity, certificate/authentication policy, AEAD
integrity, QUIC recovery, flow control, congestion control, and path validation
remain trusted properties of the selected shell stack. This project should not
implement QUIC/TLS crypto or mark QUIC/TLS as verified unless a future decision
selects a maintained verified dependency and updates the threat model. The shell
contract must define the authenticated stream-byte interface and keep transport
policy out of verified DNS logic.

## DR-0012: Prefer MsQuic for the Shell QUIC/TLS Stack

**Status:** Accepted

**Context:** The unverified shell needs a maintained QUIC/TLS implementation
with a strong security posture and a narrow integration surface for passing
authenticated stream bytes into the verified core. Candidate stacks include
MsQuic, quiche, ngtcp2, and LSQUIC.

**Decision:** Prefer MsQuic for the shell QUIC/TLS stack. MsQuic provides a C
API, mature object boundaries for listener/connection/stream ownership, active
maintenance, documented API stability expectations, and a security posture that
includes a published threat model and automated stress, fuzzing, sanitizer, and
static-analysis coverage. Keep quiche as the fallback if a Rust shell becomes
desirable, and ngtcp2 as the fallback if maximum C-level control is more
important than integration simplicity.

**Consequences:** Shell integration work should target MsQuic first and shape
the shell/core boundary around MsQuic stream callbacks: authenticated bytes from
MsQuic into verified DoQ handling, and serialized response bytes from verified
code back to MsQuic. The stable container pins upstream MsQuic `v2.5.9` headers
and shared library artifacts, checks the source commit before building, uses
`make msquic-runtime-compile-smoke` to check the stream, listener, and
connection callback wrappers against the real API shape,
`make msquic-runtime-connection-smoke` to link and run a fake-API behavioral
check for listener new-connection handling, peer-started stream slot mapping,
stream callback installation, shutdown cleanup, and rejected-stream closure,
`make msquic-runtime-link-smoke` to link and run a no-network
`MsQuicOpen2`/`MsQuicClose` load check, and
`make msquic-runtime-lifecycle-smoke` to open and close a registration,
configuration, and listener without starting socket I/O.
`make msquic-runtime-listener-smoke` starts a loopback listener on an ephemeral
local port and then stops it without accepting connections or sending traffic.
`make msquic-runtime-stream-smoke` runs a live loopback client/server stream
exchange with test-only credentials, permits one incoming bidirectional stream,
sends a valid DoQ query, asserts that the server receive callback boundary copies
real MsQuic stream bytes into shell-owned storage, submits the generated response
through `StreamSend`, checks the exact bytes received by the client, and observes
server-side send completion.
The current connection wrapper accepts listener `NEW_CONNECTION` events, applies
configuration, maps peer-started streams into fixed shell-owned slots, and
installs the existing stream callback. The stream runtime retains its MsQuic
buffer descriptor and completion context until `SEND_COMPLETE`, and the adapter
rolls verified send ownership back on submission failure. Production polling,
timer, event-loop, allocation, and multi-send integration remain future shell
work. Revisit this decision if
MsQuic's API, maintenance, platform support, or security process no longer fits
the project.

## DR-0013: Evaluate Pulse Before Any Low* Migration

**Status:** Accepted

**Amendment:** DR-0017 advances from evaluation to a planned incremental
Pulse-to-C migration, retaining this decision's no-regression promotion gates.

**Context:** The stable repository lane is pinned to F* `v2026.03.24` because
F* `v2026.04.17` removed the old Low* sublanguage. The project still relies on
legacy Low*/KaRaMeL APIs for executable verified boundaries, while the parser
strategy already points toward EverParse-generated production C.

**Decision:** Treat Pulse as a migration evaluation track, not as an accepted
broad rewrite. Keep the stable lane on F* `v2026.03.24` until a migration lane
proves that the replacement strategy preserves verification, extraction, and
shell-integration behavior. Evaluate three post-Low* options in that lane:
Pulse for verified mutable/stateful code, EverParse-generated C boundaries for
parser-heavy surfaces, and a pinned legacy Low*/KaRaMeL toolchain for code that
cannot be migrated safely yet.

**Consequences:** Do not start a broad Low* to Pulse conversion on mainline.
Use a small transport or shell-boundary module as the first Pulse pilot, because
the parser production path is EverParse rather than Pulse. Promotion of Pulse
requires successful verification on a current F* release, a clear extraction or
integration story, updated trusted-boundary documentation, and no regression in
the existing containerized `make verify`, `make extract`, `make
c-compile-smoke`, and `make c-link-smoke` gates.

## DR-0014: Evaluate Recent F*, Pulse, and Rust as the Long-Term Path

**Status:** Accepted

**Amendment:** DR-0017 separates Pulse/toolchain migration from Rust. The active
migration target is C; the Rust evaluation and Rust-specific gates below remain
experimental and are not prerequisites for Pulse/C promotion.

**Context:** Recent F* releases have moved the ecosystem away from the old Low*
sublanguage and toward Pulse for verified mutable and concurrent programming.
Pulse can extract to Rust, and Rust would reduce the shell and integration
attack surface compared with handwritten C. The repository still has a working
stable lane based on F* `v2026.03.24`, Low*/KaRaMeL extraction, EverParse C
parser generation, and C smoke gates. Pulse-to-Rust extraction is promising but
must be validated against this project's boundary, performance, dependency, and
FFI requirements before it replaces the current path.

**Decision:** Treat recent F*, Pulse, and safe Rust extraction as the preferred
long-term migration direction, but keep it behind the non-blocking migration
lane until proven by an end-to-end pilot. The first pilot should be a small
transport or shell-boundary module that verifies on a current F* release,
extracts to safe Rust, and can be called from the selected QUIC/TLS shell
without widening the trusted boundary. EverParse remains the production parser
path during this evaluation, and the stable Low*/KaRaMeL lane remains the
mainline build until the Pulse/Rust path preserves verification, extraction,
and shell integration.

**Consequences:** Do not start a broad rewrite to Pulse or Rust on mainline.
Use the migration lane to compare generated Rust quality, ghost erasure,
borrow/reference shape, FFI ergonomics, dependency surface, and CI cost. Promote
Pulse/Rust only after the pilot proves that the generated code is safe,
maintainable, and compatible with the threat model. If the pilot fails, keep
Pulse as a proof-track option and continue reducing Low*/KaRaMeL warning debt or
using narrow trusted Rust/C shell adapters.

**Promotion Gates:** A Pulse/Rust wrapper may move from migration evidence to a
checked production boundary only when all of the following are true:

- the extern ABI is stable, documented, and limited to C-friendly value types or
  explicitly owned buffers;
- ownership, aliasing, lifetime, and error-state rules are documented in
  `docs/UNVERIFIED_SHELL.md` and reflected in `docs/THREAT_MODEL.md`;
- the generated Rust still verifies, extracts, compiles, links from C, and runs
  through `make pulse-rust-smoke` in CI;
- generated Rust has been reviewed for ghost erasure, panic behavior, integer
  semantics, dependency surface, symbol naming, and layout assumptions;
- any unverified Rust adapter remains small, auditable, and free of DNS policy,
  QUIC/TLS behavior, allocation policy, and scheduling logic;
- the wrapper can either replace a current C/Low* boundary with no loss of
  coverage, or coexist with it behind a documented shell adapter during a
  bounded migration period;
- stable-lane gates still pass: `make verify`, `make extract`, and the relevant
  C smoke gates.

**Pilot Result:** The first migration-lane Pulse shell-boundary pilot verifies
on F* `v2026.05.10` and emits a KaRaMeL `.krml` artifact. The ref-based pilot is
not yet usable for Rust extraction: KaRaMeL reports that the generated pilot
depends on `Pulse.Lib.Reference.op_Bang`, which has no corresponding runtime
implementation in the current toolchain. A second value-state pilot avoids
Pulse references, uses `FStar.UInt32.t` for the FFI-visible state, and translates
to safe Rust when the unused `C` support module is dropped from the Rust backend
pass. The generated value-state Rust now compiles and runs through the
migration-only `make pulse-rust-smoke` gate, which also builds an unverified
extern-friendly Rust `staticlib` wrapper and links it from C using only
`uint32_t`/`uint8_t` value fields. This keeps Pulse viable as a proof and
state-modeling path, but the Rust promotion path should favor
extraction-supported value-state APIs unless Pulse reference runtime support is
proven.

## DR-0015: Defer Aeneas Until a Concrete Rust Audit Use Case Exists

**Status:** Accepted

**Context:** Aeneas verifies Rust programs by translating Rust, through Charon
LLBC, into functional representations for proof assistants including F*. This
direction is useful for Rust-first code, while this project's main verification
direction remains F*/Pulse to extracted Rust. Running Aeneas over generated Rust
would not replace the source F* proof or prove the extraction pipeline itself.

**Decision:** Do not add Aeneas to the active toolset, CI, or build gates yet.
Keep it as a possible future audit tool for small, Rust-first boundary code
only, such as handwritten extern wrappers, status/result mapping, buffer
capacity checks, and panic-free adapter logic around extracted Rust. Revisit
Aeneas only when there is a clear, realistic, and practical use case with a
small target module and concrete properties worth proving.

**Consequences:** Aeneas work should not appear as an active TODO, and the
project should not spend toolchain or CI budget on it speculatively. If a future
Rust shell adapter or Pulse/Rust wrapper introduces enough handwritten safe Rust
to justify additional proof effort, evaluate Aeneas in the migration lane first
and keep the trusted-boundary inventory current if the evaluation adds any new
adapter assumptions.

## DR-0016: Scope proofs explicitly and reject unsupported audit cases

**Status:** Accepted (2026-09-12)

**Context:** The September proof audit found functional defects that satisfied
weak contracts and documentation that overstated component guarantees.

**Decision:** Keep names in wire order with original spelling, use shared ASCII
case-folded equality, and convert explicitly to a distinct TLD-first tree key.
Resolve compression only through structural name-field suffix offsets and
decreasing targets. Reject relocating compressed name-bearing RDATA until it has
a typed semantic representation. General serialization is checked construction:
success must round-trip through the reference parser, even at the cost of an
additional parse. Compare abstract byte values by their contents.

Require exact DoQ framing, a zero message ID, and peer FIN before processing.
Preserve active/available stream slots by swapping, and state sequential mutation
and value contracts. Cache insertion must check its declared authority-zone
suffix and record shape; lookup returns an aged TTL under trusted time.

**Proof boundary:** Buffer parsing must relate accepted packets to actual input
snapshots. Pure model equivalence is not external EverParse equivalence. Do not
invent validator semantics, cryptographic authenticity, or ownership axioms.
Use explicit serialized/exclusive caller access until real concurrent invariants
exist. Full DNS semantics, generated-validator completeness, production worker
extraction/integration, and real concurrency remain separate promotion gates.

**Toolchain:** Pin stable KaRaMeL to
`11bb8e1ac2f720fb7144b9b768c7251526caa149`, the audited working image revision.
This does not lock the entire base image or transitive package supply chain.

**Consequences:** Update the README, architecture, parser contract, roadmap and
trusted inventory together; retain the audit's counterexamples as regressions
with corrected expected outcomes; rerun verification, extraction, generated
parser checks and C/runtime gates. No admissions are introduced by this decision.

## DR-0017: Migrate to Pulse with C Extraction Before Updating the Stable Toolchain

**Status:** Accepted (2026-09-18); M1 implemented in DR-0018, M2 in DR-0019,
M3 in DR-0020; M4 started in DR-0021, M5 planned;
stable pins unchanged.

**Context:** The existing migration pilots verify on the evaluated F*
`v2026.09.13`, but are not replacements for the actual Low* boundaries. Their
limited semantics, missing integration, and the repository's legacy build/API
dependencies require project work. No blocking Pulse language feature gap has
been established. The reference pilot's failure in the configured Rust backend
does not establish a Pulse-to-C limitation.

**Decision:** Adopt an incremental Low* to Pulse implementation/proof migration
and subsequent stable toolchain update, following M1–M5 in
[PLAN.md](PLAN.md#cross-cutting-pulse-migration-and-toolchain-update). Keep
KaRaMeL as the C extraction tool, EverParse as the parser generation path, and
the existing C/MsQuic shell. Retain pure F* models where practical. Rust remains
an independent experiment; neither its success nor failure determines C-path
promotion. This amends the implementation targets in DR-0004, DR-0013, and
DR-0014, not their requirement to preserve verified contracts and integration.

**Scope:** First preserve the existing sequential behavior and caller-owned
buffer contracts. Port a real stream ingress boundary, extract and integrate
its C output, then migrate remaining imperative surfaces. Reuse a shared
semantic specification and prove each replacement implements it; passing
fixtures alone is insufficient. Document any temporary mixed-toolchain C ABI.
The shared model must cover exact framing, FIN, zero ID, terminal/error states,
and the relevant ownership and mutation obligations, not just buffer capacity.

**Toolchain promotion:** Evaluate an explicitly pinned compatible F*/KaRaMeL/
solver set, initially using `v2026.09.13` as an evaluated candidate rather than
an automatic new stable pin. Keep separate artifacts and required baseline/
candidate checks for the migrated scope; latest-release exploration stays
non-blocking. A separately pinned EverParse generator may coexist through
validated C artifacts. Promote only after the full intended verification
surface, EverParse, C extraction/compile/link, and existing MsQuic runtime
smokes pass with the migrated implementation. Review generated code, trusted
boundaries, warnings, and resource regressions; update build configuration and
documentation together, with baseline pins and rollback instructions retained.

**Consequences:** No broad rewrite or toolchain switch is performed by this
planning change. Do not weaken contracts, add admissions, silently omit failing
modules, or widen trusted interfaces to make promotion pass. Explicit retirement
of unused legacy code requires caller and proof-coverage review. Full DNS
semantics, external-validator equivalence, genuine concurrent ownership, and
production worker expansion remain separate from preservation of current
guarantees. Update the trusted inventory as actual boundaries change.

## DR-0018: Pin a Separate Pulse/C Candidate with Explicit M1 Gate Scope

**Status:** Accepted (2026-09-19).

**Amendment:** DR-0019 and DR-0020 expand the original pilot-only scope below
with real stream proofs, C extraction and mixed runtime integration. They do not
promote the stable toolchain or make the optional Rust track a C-path gate.

**Decision:** Keep the stable Containerfile and its F*/KaRaMeL pins unchanged.
Use `Containerfile.candidate` and `migration/toolchain.lock` for the evaluated
F* `v2026.09.13` Linux x86_64 bundle, verified by SHA-256. Validate its F* commit,
bundled KaRaMeL `9abbb865b10a0cd5c557da81c024c3965cb6ff53`, and Z3 4.8.5/4.13.3/
4.15.3 identities; explicitly select bundled Z3 4.13.3. Record the actual C
compiler/target/OS and the separately pinned EverParse generator. Do not claim
fully reproducible binaries while base-image and system-package inputs float.

`make candidate-check` and the blocking candidate CI job verify both existing
pilots and extract/compile/link/run **only the pure value pilot** as C. Use the
generated header directly. Neither this C smoke nor pilot verification proves
real stream semantics, reference/buffer C support, or runtime integration.
Those are M2/M3 gates. Rust is absent from the candidate image and job; latest
release and Rust exploration are independent non-blocking scheduled/manual
checks, never fallbacks for a failed candidate gate. Repository branch-protection
settings are outside this change; the workflow itself does not tolerate a
candidate failure.

**Build discipline:** Pass one root to each verification invocation for current
`fly_deps`; retain every previous verification/extraction root. Isolate candidate
and exploration caches, `.krml`, C, and generated-parser output from stable
artifacts. Invoke the selected F* explicitly from KaRaMeL, then translate the
module-named `.krml` in a separate step: the bundled one-step C driver expects
`out.krml`, which this F* no longer emits for this invocation. Make installed
release caches readable to unprivileged container users without making the
toolchain writable. No unchecked replacement library is introduced.

**Inventory:** Maintain [PULSE_MIGRATION_INVENTORY.md](PULSE_MIGRATION_INVENTORY.md)
for all source/interface files, their current gates, contract limits, and
dispositions. A checked lexical dependency/caller report supplements manual
ABI review; it is not a proof of contract equivalence. Changing source coverage
without updating the inventory fails M1. Removed Low*/HyperStack/Steel APIs and
pure-library compatibility changes, including `Prims.op_Addition` in `DNS.Name`,
remain explicit porting work. No existing contracts or trusted interfaces change.

## DR-0019: Share Stream Semantics and Prove the Real Pulse Ingress Port

**Status:** Accepted (2026-09-20); M2 implemented. M3's subsequent extraction/
integration is recorded in DR-0020; M4/M5 and stable promotion remain open.

**Decision:** Factor `DNS.QUIC.StreamModel` as heap-independent F* checked by
both pinned compilers. Keep the stable `StreamMapping` public datatype/C shape
and use proved round-trip representation conversions. Preserve its existing
state, liveness, bounds and mutation contracts, and strengthen ingress/copy
postconditions to specify every copied byte and unchanged message byte. Share
the actual transition and bounded-copy plan, not a separate capacity model.
Use a distinct shared-model constructor order to prevent the pinned KaRaMeL's
cross-module enum-tag deduplication from renaming the public stable tags.
Add compile-time C audit guards for all stable constructor values and their
one-byte tag type. Phase conversions must remain explicit, not raw tag casts;
the model's representation is not the shell ABI.

Implement `DNS.Migration.PulseStream` over real Pulse reference/array resources.
Require separated, fully owned context, message and input storage, preserve
input bytes and context identity fields, and prove exact phase/copy results.
FIN retains message ownership and content. The copy loop has a decreasing
counter and byte-exact invariant. No raw allocation/free, assumed ownership,
new admissions, authentication axiom or concurrency permission is introduced.
Read-only fractional input borrowing remains possible future work, not a
current guarantee. C callers do not yet establish these Pulse resources.

**Preservation scope:** Keep split-prefix and body processing, exact declared
length/FIN/zero-ID behavior, terminal states, excess-byte rejection, mutation
bounds and the existing body-fragmentation lemma. Define valid phases and prove
valid-input preservation. Do not silently change historical behavior of invalid
typed states: for example, zero-ID FIN on `AwaitingFin 0` still returns
`Processing 0`. Invalid body states reject as before; rejected fragments can
still copy a bounded body prefix. Raw invalid C phase codes are an M3 adapter
concern. This is preservation of written component contracts, not a theorem
of RFC completeness or full-stream fragmentation equivalence.

**Gates:** Add `candidate-stream-verify` to the required candidate check, covering
the shared model/regressions and real Pulse implementation/imperative proof
tests. Keep existing audit tests and add closed/invalid-state regressions. The
checked inventory now includes all migration F* modules, with no mainline root
removed; transport test modules are verification-only. Stable extraction and
the C/MsQuic regression gates continue to exercise the Low* implementation.
Candidate C smoke remains the old value-only pilot: extracting, reviewing and
integrating the real Pulse stream port is M3. Keep stable pins and trusted C
interfaces unchanged. See [inventory](PULSE_MIGRATION_INVENTORY.md) for evidence
and the [trusted boundary](THREAT_MODEL.md) for unresolved caller obligations.

## DR-0020: Integrate the Pulse Stream Port Through a Versioned C-Only Boundary

**Status:** Accepted (2026-09-22); M3 implemented, M4/M5 open.

**Decision:** Extract the real `DNS.Migration.PulseStream` reference/array port
and shared model with the pinned candidate bundle. Use F*'s checked extraction
pass (no `--lax`) with default cross-module inlining and the bundle's
`Pulse.Lib.Pervasives` helper. Do not introduce assumed runtime implementations
for reference/array primitives. Use executable `SizeT.uint32_to_sizet` conversions
under the original proved bounds. Review erased proofs, C integer operations,
loop bounds and dependencies; make extraction warning 250 and KaRaMeL warnings
2/4/15 fatal for this port. Compile new C components with strict warnings.

Join independently built components through ABI version 1 in
`migration/c/ism_pulse_stream.h`: fixed-width phase fields, shell result code,
stream ID and explicit byte pointers/capacities. Compile
`migration/c/ism_pulse_stream.c` only against candidate headers and
`shell/pulse_stream_adapter.c` only against stable headers. Convert phases by
named cases, not generated-layout casts. Assert native layout and require a
matching C target. No checked files, `.krml` artifacts or generated header types
cross compiler lanes. Keep the stable public shell/context/response ABI intact.

**Ownership and trust:** These two C marshalers are explicitly unverified TCB
additions. They validate representable tags/lengths, descriptors, byte-range
separation and ABI identity, but raw C cannot prove live allocations, truthful
capacities, authentication or exclusive access. The real receive path copies
MsQuic input into runtime-owned ingress storage before synchronous dispatch.
Callers still supply disjoint context/message/input and serialized operations.
Candidate context storage is stack-local; no allocation or retained pointer is
introduced. Preserve historical typed invalid-state behavior, including
`AwaitingFin 0`; raw unrepresentable tags/lengths reject before buffer access.
See [PULSE_C_ABI.md](PULSE_C_ABI.md) for exact mappings, lifetime and rejection
rules, and [THREAT_MODEL.md](THREAT_MODEL.md) for unresolved obligations.

**Integration and evidence:** Extend `candidate-check` to require real stream C
tests separately from the value pilot. Record hashes of source/build inputs and
C products, tool pins/provenance and target; fail on stale or foreign artifacts
and unexpected archive/runtime dependencies. The manifest detects accidental
drift, not malicious provenance. `pulse-integration-check` runs in the stable
image after candidate extraction, compiles the actual shell with Pulse selected,
and checks its unresolved symbols to exclude legacy ingress/FIN calls. Use that
same shell object for the existing C and MsQuic callback/live-loopback tests.
Compare the stable and Pulse adapters on phase, result and all message bytes.
Add the mixed gate to blocking CI while retaining the independent candidate job.

**Limits and rollback:** Only ingress/FIN is replaced in the explicit mixed
lane. Stable defaults, pins, EverParse, table lifecycle, worker, response, reset
and completion stay unchanged. Restore the Low* path simply by using ordinary
stable targets without Pulse overrides. Tests and C review supplement the M2
correspondence proofs; they do not prove the adapters, global ownership,
authentication, concurrency, full DNS semantics or full-stream fragmentation.
No new source admissions or ownership axioms are added. Remaining imperative
ports, warning/resource review and whole-toolchain promotion remain M4/M5.

## DR-0021: Start M4 with an Owned Pulse Stream Table and Standalone C Gate

**Status:** Accepted (2026-10-01); first M4 slice implemented, runtime table
integration and the remaining M4 modules are still open. Stable pins unchanged.

**Amendment:** DR-0022 subsequently adds the separate table-enabled runtime lane;
the first-slice scope below records the original standalone proof/C milestone.

**Decision:** Port lookup, allocation and close to
`DNS.Migration.PulseMultiplexer` using real Pulse references and pointer arrays.
Share ghost slot distinctness/permutation lemmas in `DNS.QUIC.TableModel` with
the retained stable multiplexer. Track full context ownership using a fixed
ghost pool and snapshot, separately from the mutable table permutation. Prove
finite lookup, take/restore and snapshot-update helpers; introduce no assumed
ownership conversion or choice axiom. Message resources are framed: table
operations preserve buffer identity and never read, write, allocate or free
message storage. Here allocation means reserving an existing context slot.

**Contracts and limits:** Lookup returns the first matching active index, or
the active count on a miss. Allocation returns capacity on duplicate/full
rejection with no mutation; success resets exactly the first available context's
ID and phase, retains its buffer and every other context, and increments count.
Close swaps the first matching pointer with the last active pointer and
decrements count, preserving every context and the pool permutation; a miss
changes nothing. All operations require separate, fully owned connection,
table and distinct pool contexts, even for an empty active prefix. This is
stronger than the legacy conditional lookup/close preconditions, and the
index/sentinel API is not its option-pointer ABI. Preserve caller-framed buffer
liveness explicitly when composing with ingress; neither arbitrary raw C
pointers nor message ownership are established by these table predicates.

**Gates:** `candidate-check` requires the new shared and imperative proof tests,
checked C extraction with cross-module inlining, fatal F* warning 250 and
KaRaMeL warnings 2/4/15, and strict standalone C compile/link/run. Keep artifacts
in their own `pulse-multiplexer` directory. Test actual pointer permutations,
empty/full/duplicate/missing cases, retired-slot reuse, context/byte preservation
and zero/max stream IDs against an integer-index oracle. These finite tests
supplement the universal contracts; they are not a Low*/Pulse equivalence
theorem or a verified C caller. No tests or legacy proof roots are removed.

**Integration boundary:** Do not pass candidate generated structs to the stable
shell or reinterpret stable context pointers. The existing mixed lane still
selects only Pulse ingress/FIN; stable table lifecycle and completion remain
unchanged. Next design and review a C-only table seam and its initialization,
context identity, lifetime and ownership obligations before selecting the new
table in runtime tests. No new unverified adapter is added by this slice, and
passing it does not complete M4 or permit M5 toolchain promotion.

## DR-0022: Integrate Pulse Table Lifecycle Through Bounded C Snapshots

**Status:** Accepted (2026-10-01); M4 table integration slice. Remaining imperative
proof ports and stable toolchain promotion remain open. This extends DR-0021's
standalone scope without replacing the default table or the M3-only lane.

**Decision:** Add the versioned C-only boundary in `ism_pulse_table.h`, with four
physical slot identities and an active/available permutation matching the current
shell capacity. Snapshot IDs, explicit neutral phases and message descriptors;
materialize real separate candidate references/pointer arrays locally; invoke the
verified table operations; map results back to the original embedded shell slots.
Never cast generated context types across compilers, relocate message storage or
retain candidate pointers. Share named phase conversions with the M3 adapters.

**Behavior:** Preserve shell idempotent open by finding before allocating. Route
shell find/open and reset/direct-completion/dispatched-completion close through
Pulse in `pulse-table-integration-check`. Preserve the legacy return 1 for a
missing close and the existing active-flag/retired-slot synchronization. Both send
outcomes still close without accessing response bytes. Reject malformed metadata,
permutations, phase encodings, capacities and alias ranges before writeback.
Full shell initialization, embedded buffer identity and active-prefix consistency
are required; this is not support for arbitrary foreign context pools.

**Trust:** The two new C table adapters and selected cleanup dispatch are unverified
trusted code. The candidate proof owns the local materialized heap; snapshot and
persistent-shell writeback correspondence are supported by review and differential
tests, not a new theorem. Live allocations, truthful capacities, response lifetimes,
exclusive access and callback serialization remain caller/runtime obligations.
There is no new F* admission, assumed Pulse primitive or concurrency permission.
The stricter boundary is documented in [PULSE_TABLE_C_ABI.md](PULSE_TABLE_C_ABI.md).

**Gates:** Retain standalone tests and add ABI rejection tests and a checked table
C archive/manifest. Check compiled shell and adapter symbols for actual selection
and absence of old cleanup entry points. Compare the selected shell against an
independent compilation of the actual baseline, including pointer identity,
permutation/count, flags, phases, bytes and close/reopen/ingress composition. Run
all existing C/MsQuic tests on that same shell object. Keep default, M3-only and
table-enabled lanes separate and required in CI; no candidate generated headers,
checked files or `.krml` inputs enter stable compilation.

**Remaining work:** Worker/response wrappers retain their internal read-only Low*
lookups and sequential proofs; egress and send-buffer/completion ownership proofs
are not migrated here. Port those boundaries next, followed by the remaining
worker/parser/cache/security inventory. No API or proof is silently retired.
Use the normal stable build, or M3-only integration, to roll back table selection.

## DR-0023: Prove Response Framing Against a Shared Byte-Level Model First

**Status:** Accepted (2026-10-02); bounded M4 response proof slice. Candidate
response C extraction/integration, descriptor/completion ownership and M5 remain
open. Stable pins and runtime response selection are unchanged.

**Decision:** Share `DNS.QUIC.ResponseModel` between the stable response boundary
and `DNS.Migration.PulseResponse`. Prove exact two-byte big-endian framing,
prefix decode round trip, payload copying, source preservation and unchanged
destination tail. Oversized payloads and insufficient capacity return zero
without writes; check the 65535-byte bound before addition. Retain the existing
zero-length behavior (two zero prefix bytes), not a new DNS validation policy.

**Contracts:** Strengthen the stable wrapper's postcondition, preserving all
existing preconditions, context contents and public signatures. The recursive
legacy copy helper still accepts aliased buffers; its new snapshot-copy/source
preservation postcondition is conditional on disjointness rather than imposing
a stronger precondition. The wrapper already requires that separation.
Pulse framing uses real separately owned arrays with truthful source length and
destination capacity, preserving compatible caller-framed resources. Reuse the
verified Pulse copy loop. Do not introduce an assumed primitive, ownership
conversion or platform-width axiom. Large imperative test fixtures take actual
representable `SizeT` lengths; they do not assume every target is at least 32-bit.

**Gates:** Require shared and imperative response proof regressions in
`candidate-check`, with the focused `candidate-response-verify` target and an
isolated response proof cache. Mark all candidate response roots proof-only in
the checked inventory; stable extraction includes the shared executable helpers
but excludes proof tests. Retain all previous proof/C/runtime gates. Add stable
generated-C framing regressions covering exact/short capacities, empty and
maximum lengths, prefix byte boundaries, every input/output byte, context and
guard preservation. These C tests do not exercise the Pulse response port.

**Limits and next gate:** This proves synchronous framing, not construction of
a semantically correct DNS response, FIN/descriptor correspondence, immutable
borrow until asynchronous completion, callback serialization or safe buffer
recycling. Existing unit egress/borrow tokens remain explicit trust debt. No
adapter or trusted interface is added. Next extract and review the Pulse framing
code and integrate it through a C-only seam with explicit caller obligations;
then migrate descriptor/completion ownership and the remaining M4 surfaces.

## DR-0024: Integrate Pulse Framing While Retaining the Stable Descriptor Handoff

**Status:** Accepted (2026-10-02); M4 response framing C integration slice.
This extends DR-0023's proof-only milestone, not asynchronous send ownership or
whole-toolchain promotion. Stable pins and default selection are unchanged.

**Decision:** Extract `DNS.Migration.PulseResponse` with checked candidate F*
extraction, cross-module inlining and the bundled Pulse library. Make extraction
warning 250 and KaRaMeL warnings 2/4/15 fatal and compile the generated C and new
adapters with strict warnings. Keep the shared byte-level proofs and all prior
proof roots. Require standalone direct/ABI C tests and a checked response archive
manifest in `candidate-check`.

**Boundary:** Use ABI version 1 in `ism_pulse_response.h`, passing only byte
pointers, native capacities and uint32 lengths. Separate candidate and stable
translation units; no generated types, checked files or `.krml` cross lanes.
Validate capacities, address overflow, alias ranges and context separation.
Do not add an assumed ownership bridge. Preserve zero-length framing, no-write
rejection, source/tail/context contents and public shell signatures. Keep the
stable descriptor handoff with the same context, framed length and FIN code
after the Pulse copy; raw unframed sends are unchanged.

**Trust and scope:** Two C response adapters and native range checks are new
unverified TCB. Callers still establish real liveness, truthful sizes, exclusive
access and serialization. The shell API exposes only the used source prefix;
the adapter borrows that prefix and never reads or writes the unused tail.
No allocation or retained pointer is introduced. No F* contract is weakened,
admission added, or send-lifetime theorem claimed. See the
[response ABI review](PULSE_RESPONSE_C_ABI.md) and trusted inventory.

**Runtime gate and rollback:** Add a separate `pulse-response-integration-check`
lane selecting ingress/FIN, table lifecycle and response framing. Check compiled
selection and retained descriptor handoff; compare the actual selected shell
against independently compiled baseline code, then run all existing C/MsQuic
gates on the same shell object. Keep default, M3-only and table-only lanes
required and available for rollback. Descriptor/completion ownership, worker/
parser/cache/security ports, warning/resource review and M5 remain open.

## DR-0025: Seal Pending Send Ownership in a Proof-Only Pulse API

**Status:** Accepted (2026-10-02); bounded M4 proof slice, not runtime migration.

**Decision:** Add `DNS.Migration.PulseSend` with a checked interface and
implementation. An idle slot owns the response array and connection/table/context
pool. Beginning a send rejects a missing stream without mutation, or records the
exact buffer, stream ID, length and FIN and seals those resources in `pending`.
Inspection preserves that resource. Mismatched modeled completion retains it;
matching completion or drop closes the first matching active slot, preserves all
context values and bytes, and returns the idle slot and writable response storage.
Also expose exact pointer equality in the stable egress postcondition, without
changing its preconditions, implementation or ABI.

**Conservative domain:** The existing table operations require the complete
context pool, so this first API reserves the entire connection/table/pool until
completion. Other independently owned storage can be framed, but unrelated
streams in that connection cannot be operated on through this API while pending.
This is a stronger ownership requirement than the runtime and is not a drop-in
contract-equivalent replacement. Refine the reservation before integration.

**Trust:** The abstract predicate is implemented by real reference/array
ownership; the gate checks its implementation before clients. It is not a unit
token or an assumed ownership axiom. A matching ID is only a modeled notification,
not evidence of MsQuic quiescence. Truthful completion/drop after transport release,
serialized callbacks, raw-pointer lifetime and same-ID replay/generation handling
remain external obligations. The existing runtime and its unit borrow tokens are
unchanged. No C adapter or new runtime assumption is introduced by this slice.

**Gates and follow-up:** Require `candidate-send-verify` in `candidate-check`,
with an isolated proof cache and no send extraction. Test framing-to-send,
descriptor fields, mismatch preservation, both outcomes and recovered ownership;
four expected resource-error clients reject early writes/close, double begin and
completion without pending ownership. These negative tests are not admissions.
Then refine per-stream reservations and notification identity, extract/review a
C-only ownership boundary, and integrate with existing C/MsQuic tests. M4/M5 and
end-to-end asynchronous lifetime guarantees remain open.

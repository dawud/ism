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
code back to MsQuic. The stable container pins the upstream `msquic.h` header
and the `make msquic-runtime-compile-smoke` CI gate checks the callback wrapper
against that real API shape. Pin the chosen MsQuic library version or commit
before production use, document build/link dependencies, and revisit this
decision if MsQuic's API, maintenance, platform support, or security process no
longer fits the project.

## DR-0013: Evaluate Pulse Before Any Low* Migration

**Status:** Accepted

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

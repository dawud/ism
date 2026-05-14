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
the protocol/EverParse parser boundary, `DNS.ShellBoundary` ingress ABI, and
`DNS.ShellResponseBoundary` response send handoff/completion ABI.
KaRaMeL still reports warning-15 diagnostics for GC-backed lists,
mathematical integers, and specification-oriented definitions. The current
extraction gate verifies all scaffold modules but only emits a clean parser,
authenticated-ingress, and response send handoff/completion link surface.

**Decision:** Treat current extraction as a generated-artifact smoke test, not
proof that generated output is production C. Classify warning-15 debt as
specification-only code, executable code needing Low* rewrites, compatibility
header use, or generated/trusted adapter boundary work.

**Consequences:** Extraction warning debt must be reduced or explicitly
classified before extraction becomes a production gate. Worker
response-construction and dispatcher C link coverage remain separate follow-up
work once those symbols are rewritten or emitted in a stable shell-facing form.

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
code back to MsQuic. Pin the chosen MsQuic version or commit before production
use, document build/link dependencies, and revisit this decision if MsQuic's API,
maintenance, platform support, or security process no longer fits the project.

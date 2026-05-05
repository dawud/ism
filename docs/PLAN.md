# High-Assurance DNS-over-QUIC Server: Implementation Plan

This document outlines the design, architecture, and phased implementation of a mathematically verified DNS-over-QUIC (DoQ) server using F*, Low*, and the Project Everest ecosystem.

## 1. Project Objectives
- **Mathematically Proven Safety:** Eliminate buffer overflows, use-after-free errors, and data races through formal verification.
- **Modern Standards Compliance:** Implement DNS-over-QUIC (RFC 9250) using TLS 1.3 (RFC 8446).
- **Single-Binary Multi-threading:** High-performance execution using a task-based scheduler without relying on process isolation.
- **Parser-Rejecting Security:** Discard malformed or unauthorized packets at the verification boundary before they reach the logic core.
- **Post-Quantum Readiness:** Support for Hybrid Key Exchange (X25519 + ML-KEM) to protect against future quantum adversaries.

## 2. High-Level Architecture

The server follows a "Defensive Ring" architecture, separating the unverified I/O shell from the verified logic core.

### Architectural Layers
1. **Unverified Shell (C):** Handles POSIX sockets, thread scheduling, and initial UDP packet reception.
2. **Secure Gateway (EverCrypt):** Handles TLS 1.3 handshake, authenticated decryption (AEAD), and session key derivation.
3. **The Gatekeeper (EverParse):** Validates the DNS wire format against the formal specification. Rejects any non-conforming input.
4. **Verified Core Logic (F*):** Implements Radix Tree lookups, Wildcard matching, and CNAME chasing.
5. **Concurrent Memory (Steel):** Manages the shared recursive cache using separation logic to prove the absence of data races.

---

## 3. Implementation Roadmap

Roadmap status is tracked in terms of maturity, not only feature names. A feature can be modeled and verified while still relying on trusted assumptions, local mocks, or incomplete executable behavior.

### Maturity Levels
- **Modeled:** The F* types and high-level state transitions exist.
- **Verified scaffold:** `make verify` succeeds for the obligations currently written.
- **Implemented with caveats:** Executable behavior exists, but some `admit()`, `assume`, mocks, placeholders, or incomplete semantics remain.
- **Extracted:** KaRaMeL extraction succeeds for the relevant code.
- **Integrated:** The extracted code is connected to the unverified shell or external dependency boundary.
- **Production-ready:** Trusted gaps are explicitly documented or removed, tests cover representative behavior, extraction is checked, and the feature has a clear audit trail.

### Phase Definition of Done
Each phase should only be considered complete when all of the following are true:
- No phase-critical `admit()` or `assume` remains.
- Any remaining trusted dependency is documented in the threat model.
- The code verifies with the containerized `make verify` command.
- The code extracts with KaRaMeL, or the non-extractable part is explicitly marked as specification-only.
- Representative positive and negative tests exist.
- The corresponding RFC compliance rows are updated.

### Phase 1: Formalized Wire Format & Verified Parsing
*Goal: Create a zero-copy, verified parser and serializer for modern DNS messages.*
- **Scope:** RFC 1035 (Core), RFC 3597 (Unknown RRs), RFC 6891 (EDNS0).
- **Parser Strategy:** EverParse is the long-term production parser/serializer target. The handwritten F*/Low* parser is a bootstrap/reference parser for closing DNS semantics, developing tests, and validating the Low* buffer boundary. Before Phase 1 is production-ready, the project must either replace the handwritten parser with an EverParse-generated parser or prove/document behavioral equivalence between the generated parser and the handwritten reference.
- **Tasks:**
  - Define `DNS_Packet`, `Header`, `Question`, and 43+ `Resource Record` types in F*.
  - Implement bidirectional mapping between F* sum types and IANA numeric constants.
  - Implement recursive `parse_qname` with fuel-based termination to mitigate pointer-loop attacks.
  - Stabilize the handwritten reference parser and tests.
  - Generate or integrate the EverParse parser/serializer.
  - Compare or migrate away from the handwritten reference parser before declaring Phase 1 production-ready.
- **Verification:** Prove the parser is "total" and "parser-rejecting" for all malformed inputs.

### Phase 2: DoQ Transport and TLS Security
*Goal: Establish a secure transport tunnel using miTLS and EverQuic.*
- **Scope:** RFC 9250, RFC 9000, RFC 8446.
- **Sub-phases:**
  - **2A: DNS-over-QUIC framing:** Implement the RFC 9250 two-octet DNS message length prefix, reject malformed frame boundaries, and prove bounds on frame accumulation.
  - **2B: Stream accumulation:** Implement `ReadingLength`, `ReadingMessage`, `Processing`, and cleanup transitions without admitted state changes.
  - **2C: Stream multiplexing:** Implement stream lookup/allocation/close with explicit resource bounds and denial-of-service behavior.
  - **2D: TLS/AEAD abstraction:** Replace mock decrypt success with a narrow verified or trusted interface and document the exact authenticity property exported to the DNS layer.
  - **2E: Key lifecycle:** Model epoch changes, session teardown, key zeroization, and forward-secrecy requirements.
  - **2F: EverCrypt/EverQuic integration:** Replace local mocks with real Project Everest dependencies or a documented trusted adapter.
- **Tasks:**
  - Define `Connection_Context` to manage ephemeral keys and session state.
  - Implement the QUIC Stream state machine (Accumulator) for handling fragmented frames.
  - Implement the Stream ID Multiplexer to support concurrent queries without Head-of-Line blocking.
- **Verification:** Prove memory safety for buffer copies (`blit`) and ensure keys are zeroed out after session termination (Forward Secrecy).

### Phase 3: Verified Core Logic & Backend
*Goal: Functional correctness of lookup and response generation.*
- **Tasks:**
  - Implement the **Authoritative Radix Tree** (Trie) for O(log n) lookups.
  - Implement **CNAME Chasing** with a verified hop-count limit to prevent exhaustion loops.
  - Implement **Bailiwick Validation** to prevent cache poisoning in recursive results.
  - Implement the **Verified Cache** with Steel-enforced absolute TTL.
- **Verification:** Prove that lookup functions always terminate and never leak data between query contexts.

### Phase 4: Secure Concurrency & I/O Integration
*Goal: Thread-safe execution using Steel.*
- **Tasks:**
  - Implement a **Sharded Concurrent Cache** using Steel invariants to proof the absence of data races.
  - Create the **Worker Thread Harness** to coordinate parsing, logic, and response generation.
  - Integrate with the "Unverified Shell" for UDP/QUIC socket I/O.
- **Verification:** Use F*'s separation logic to prove that threads cannot interfere with each other's memory regions.

### Phase 5: Hardening & Supply Chain Verification
*Goal: Final binary extraction and formal audit.*
- **Tasks:**
  - Extract verified F* / Low* code to C using the **KaRaMeL** toolchain.
  - Perform **Grammar-Based Fuzzing** using EverParse specs as a seed source.
  - Transition to **Post-Quantum Cryptography**:
    - Implement Hybrid ML-KEM + X25519 Key Exchange.
    - Implement ML-DSA (Dilithium) for identity verification.
- **Verification:** Compile using the **CompCert** verified compiler to ensure the final binary matches the formal model.

---

## 4. Technical Stack
| Component | Technology | Rationale |
| :--- | :--- | :--- |
| **Language** | F* / Low* | Formal verification with C extraction capability. |
| **Cryptography** | EverCrypt (HACL*) | Verified, constant-time primitives. |
| **Parsing** | EverParse | Correct-by-construction parser generation. |
| **QUIC/TLS** | EverQuic / miTLS | Verified implementations of transport security. |
| **Concurrency** | Steel | Separation logic for thread safety proofs. |
| **Compiler** | CompCert | High-assurance C compilation. |

---

## 5. Verification, Extraction, and CI

The project should run verification and extraction as separate gates:
- `make verify`: checks the F* obligations currently written.
- `make extract`: checks that verified Low*/F* code can be emitted as C through KaRaMeL.
- CI should run the containerized `make verify` on every change.
- CI should add `make extract` as soon as extraction blockers are isolated or resolved.
- A verification pass with `admit()`, `assume`, or local mocks is acceptable for scaffolding, but the corresponding proof debt must remain visible in `TODO.md` and the threat model.

Current extraction status: `make extract` completes in the pinned container and emits generated C/H files under `dist/`. This is a useful smoke test, but KaRaMeL reports many warning-15 diagnostics because large parts of the scaffold use GC-backed lists, mathematical integers, or specification-oriented definitions that are not Low*. Before extraction becomes a production gate, classify each warning as one of:
- intended specification-only code to mark `noextract` or remove from reachable bundles;
- executable code that must be rewritten into the Low* subset;
- code that can temporarily use KaRaMeL compatibility headers;
- code that should move behind generated EverParse or trusted adapter boundaries.

### F* Release Policy

The main development lane is pinned to F* `v2026.03.24`. This is the project's legacy Low*/KaRaMeL compatibility baseline and should remain the default until the codebase no longer depends on the old Low* APIs.

F* `v2026.04.17` removed the old Low* sublanguage and introduced Pulse as the new imperative separation-logic direction. Later weekly releases, including `v2026.05.03`, should be monitored, but adopting them is a migration project rather than a routine version bump.

Release management should use two lanes:
- **Stable lane:** pinned `v2026.03.24`, blocking for normal development, `make verify`, and eventually `make extract`.
- **Next lane:** latest F* weekly release, non-blocking, allowed to fail while Low*/Pulse/EverParse migration work is open.

Promotion from the next lane to the stable lane requires:
- verification succeeds without relying on new undocumented assumptions;
- extraction strategy is clear for all executable Low*/F*/Pulse code;
- local mocks and trusted adapters are reviewed against the new library contracts;
- the threat model's trusted-boundary inventory is updated;
- parser strategy remains aligned with the EverParse production target.

Review upstream F* releases on a scheduled cadence, such as quarterly, instead of automatically chasing weekly releases.

## 6. Parser and Protocol Test Plan

The parser should have executable tests even while larger extraction and integration work is ongoing. Initial tests should cover:
- valid single-question DNS query;
- truncated header;
- truncated QNAME;
- invalid label length;
- trailing bytes rejected;
- nonzero answer, authority, or additional counts currently rejected until RR parsing lands;
- unknown QTYPE accepted as `UNKNOWN`;
- malformed compression pointers rejected until compression support is implemented.

These tests should eventually run against both the pure parser and the Low* buffer boundary.

## 7. RFC Compliance Matrix

Maintain a compliance matrix for each protocol area:

| RFC | Section | Requirement | Status | Proof/Test Coverage | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| RFC 1035 | Header format | 12-byte DNS header | Partial | Parser verifies structurally | RR sections still rejected. |
| RFC 1035 | QNAME labels | Labels are length-prefixed | Partial | Pure parser and Low* buffer path | Compression is rejected for now. |
| RFC 3597 | Unknown RR types | Preserve unknown types | Partial | QTYPE maps to `UNKNOWN` | Full RR parsing not implemented. |
| RFC 6891 | EDNS0 OPT | OPT pseudo-RR | Partial | Padding helper verifies | OPT parsing/serialization incomplete. |
| RFC 9250 | DoQ framing | Two-octet length prefix | Not implemented | None | Planned in Phase 2A. |
| RFC 8446 | TLS 1.3 | Authenticated transport | Mocked | None | Mock AEAD and handshake remain. |

## 8. Threat Model Summary
- **Spoofing:** Mitigated by TLS 1.3 identity and verified Bailiwick checks.
- **Tampering:** Mitigated by EverCrypt AEAD integrity checks.
- **Information Disclosure:** Mitigated by constant-time crypto and EDNS0 padding.
- **Denial of Service:** Mitigated by Steel-enforced memory bounds and fuel-based recursion limits.
- **Elevation of Privilege:** Mitigated by EverParse-guaranteed memory safety.
- **Harvest Now, Decrypt Later:** Mitigated by Hybrid Post-Quantum Key Exchange.

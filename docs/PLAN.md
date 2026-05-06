# High-Assurance DNS-over-QUIC Server: Implementation Plan

This document outlines the design, architecture, and phased implementation of a mathematically verified DNS-over-QUIC (DoQ) server using F*, Low*, and the Project Everest ecosystem.

## 1. Project Objectives
- **Mathematically Proven Safety:** Eliminate buffer overflows, use-after-free errors, and data races through formal verification.
- **Modern Standards Compliance:** Implement DNS-over-QUIC (RFC 9250) using TLS 1.3 (RFC 8446).
- **Single-Binary Multi-threading:** High-performance execution using a task-based scheduler without relying on process isolation.
- **Parser-Rejecting Security:** Discard malformed or unauthorized packets at the verification boundary before they reach the logic core.
- **Post-Quantum Readiness:** Support for Hybrid Key Exchange (X25519 + ML-KEM) to protect against future quantum adversaries.

## 2. High-Level Architecture

The server follows a "Defensive Ring" architecture, separating the unverified I/O shell from the verified logic core. See [DECISIONS.md](DECISIONS.md) for the accepted architecture and trusted-boundary decisions.

### Architectural Layers
1. **Unverified Shell (C):** Handles POSIX sockets, thread scheduling, and initial UDP packet reception.
2. **Secure Gateway (EverCrypt):** Handles TLS 1.3 handshake, authenticated decryption (AEAD), and session key derivation.
3. **The Gatekeeper (EverParse):** Validates the DNS wire format against the formal specification. Rejects any non-conforming input.
4. **Verified Core Logic (F*):** Implements Radix Tree lookups, Wildcard matching, and CNAME chasing.
5. **Concurrent Memory (Steel):** Manages the shared recursive cache using separation logic to prove the absence of data races.

---

## 3. Implementation Roadmap

Roadmap status is tracked in terms of maturity, not only feature names. The maturity levels are defined in [DECISIONS.md](DECISIONS.md).

### Phase Definition of Done
Phase completion gates are recorded in [DECISIONS.md](DECISIONS.md). Keep this roadmap aligned with those gates when updating phase status.

### Phase 1: Formalized Wire Format & Verified Parsing
*Goal: Create a zero-copy, verified parser and serializer for modern DNS messages.*
- **Scope:** RFC 1035 (Core), RFC 3597 (Unknown RRs), RFC 6891 (EDNS0).
- **Parser Strategy:** The handwritten parser is the bootstrap/reference parser; EverParse remains the production target. See [DECISIONS.md](DECISIONS.md).
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
The accepted stack decision is recorded in [DECISIONS.md](DECISIONS.md).

---

## 5. Verification, Extraction, and CI

Verification and extraction are separate gates. Current extraction is a generated-artifact smoke test until the remaining warning-15 debt is acceptable for CI. See [DECISIONS.md](DECISIONS.md).

The extraction gate verifies all scaffold modules but only sends the current protocol/security/transport boundary to KaRaMeL. Verification-only parser tests and Phase 3/4 logic/concurrency scaffolds stay out of extraction until they are rewritten into Low* or explicitly marked as trusted/specification-only boundaries.

The remaining warning-15 debt is concentrated in the protocol model:
- GC-backed list representations in `DNS.Name` and `DNS.Protocol`;
- `dns_packet`, `question`, and `resource_record` records that still carry list-backed fields;
- trusted-adapter boundaries that should stay visible until the generated EverParse or Low* replacement exists.

### F* Release Policy

The stable lane is pinned to F* `v2026.03.24` while old Low* APIs remain in use. Track newer F* releases in a non-blocking migration lane. See [DECISIONS.md](DECISIONS.md).

## 6. Parser and Protocol Test Plan

Parser-test policy is recorded in [DECISIONS.md](DECISIONS.md). Initial tests should cover:
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

Maintain a compliance matrix for each protocol area. See [DECISIONS.md](DECISIONS.md).

| RFC | Section | Requirement | Status | Proof/Test Coverage | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| RFC 1035 | Header format | 12-byte DNS header | Partial | Pure parser tests cover valid and truncated headers; Low* buffer boundary reads the checked length. | EverParse boundary delegates to the reference parser; generated parser not integrated yet. |
| RFC 1035 | QNAME labels | Labels are length-prefixed | Partial | Tests cover valid root QNAMEs, truncated QNAMEs, invalid label length, trailing bytes, and rejected compression pointers. | Compression is rejected for now; RR sections still rejected. |
| RFC 3597 | Unknown RR types | Preserve unknown types | Partial | Executable parser test maps an unknown QTYPE to `UNKNOWN`. | Full RR parsing not implemented. |
| RFC 6891 | EDNS0 OPT | OPT pseudo-RR | Partial | Padding helper verifies | OPT parsing/serialization incomplete. |
| RFC 9250 | DoQ framing | Two-octet length prefix | Not implemented | None | Stream state types exist, but length parsing and accumulation are placeholders. |
| RFC 8446 | TLS 1.3 | Authenticated transport | Mocked | None | Mock AEAD and handshake remain. |

Extraction status: containerized `make extract` is now a CI smoke gate. It verifies all F*/spec modules first, then extracts the current protocol/security/transport boundary while Phase 3/4 scaffolds remain verification-only.

## 8. Threat Model Summary
- **Spoofing:** Mitigated by TLS 1.3 identity and verified Bailiwick checks.
- **Tampering:** Mitigated by EverCrypt AEAD integrity checks.
- **Information Disclosure:** Mitigated by constant-time crypto and EDNS0 padding.
- **Denial of Service:** Mitigated by Steel-enforced memory bounds and fuel-based recursion limits.
- **Elevation of Privilege:** Mitigated by EverParse-guaranteed memory safety.
- **Harvest Now, Decrypt Later:** Mitigated by Hybrid Post-Quantum Key Exchange.

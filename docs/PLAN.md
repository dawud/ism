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
- **Scope:** RFC 1034, RFC 1035, RFC 2181, RFC 3597, RFC 6891, RFC 7830, RFC 8467, RFC 9499.
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
- **Scope:** RFC 9250, RFC 9000, RFC 9001, RFC 9002, RFC 8310, RFC 8446, RFC 8914.
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
- **Scope:** RFC 2308, RFC 4592, RFC 5452.
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
- valid single-answer RR with bounded RDATA preservation;
- truncated RR header and RDATA rejected;
- invalid A/AAAA RDATA lengths rejected;
- valid CNAME RDATA accepted as one fully-consumed uncompressed name;
- truncated, trailing, or compressed name-bearing RDATA rejected;
- unknown QTYPE accepted as `UNKNOWN`;
- unknown RR TYPE accepted as `UNKNOWN`;
- valid EDNS0 OPT pseudo-RR accepted in the additional section;
- non-root OPT owner and unsupported EDNS version rejected;
- valid EDNS0 padding option accepted structurally;
- truncated EDNS0 option header and option data rejected;
- unknown EDNS0 option code accepted structurally;
- malformed compression pointers rejected until compression support is implemented.

These tests should eventually run against both the pure parser and the Low* buffer boundary.

## 7. RFC Compliance Matrix

Maintain a compliance matrix for each protocol area. See [DECISIONS.md](DECISIONS.md).

| RFC | Section | Requirement | Status | Proof/Test Coverage | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [RFC 1034](https://datatracker.ietf.org/doc/html/rfc1034) | DNS concepts | Authoritative data, recursion, CNAME, and wildcard model | Partial | Exact radix lookup and CNAME hop-count scaffolds exist. | Wildcard semantics, full CNAME chasing, and recursive behavior are incomplete. |
| [RFC 1035](https://datatracker.ietf.org/doc/html/rfc1035) | Header format | 12-byte DNS header | Partial | Pure parser tests cover valid and truncated headers; Low* buffer boundary reads the checked length; shared fixtures now exercise the EverParse production-target subset boundary. | External generated parser not integrated yet. |
| [RFC 1035](https://datatracker.ietf.org/doc/html/rfc1035) | QNAME labels | Labels are length-prefixed | Partial | Tests cover valid root QNAMEs, truncated QNAMEs, invalid label length, trailing bytes, and rejected compression pointers. | Compression is rejected for now, including RR names. |
| [RFC 1035](https://datatracker.ietf.org/doc/html/rfc1035) | Resource records | RR NAME, TYPE, CLASS, TTL, RDLENGTH, and RDATA fields | Partial | Tests cover one answer RR, truncated RR headers, truncated RDATA, invalid A/AAAA RDATA lengths, and name-bearing CNAME RDATA shape. | RDATA is preserved by RDLENGTH; A/AAAA length validation and NS/CNAME/PTR name-shape validation exist, while broader type-specific RDATA validation is incomplete. |
| [RFC 2181](https://datatracker.ietf.org/doc/html/rfc2181) | DNS clarifications | RRset, TTL, CNAME, and ranking clarifications | Partial | TTL validity and saturated expiry calculations exist. | RRset semantics, trust ranking, and full CNAME rules are incomplete. |
| [RFC 2308](https://datatracker.ietf.org/doc/html/rfc2308) | Negative caching | Cache NXDOMAIN/NODATA and TTL behavior correctly | Not implemented | None | Recursive cache lookup/insertion are still admitted. |
| [RFC 3597](https://datatracker.ietf.org/doc/html/rfc3597) | Unknown RR types | Preserve unknown types | Partial | Executable parser tests map unknown QTYPE and RR TYPE values to `UNKNOWN`, and RR RDATA is preserved by RDLENGTH. | Presentation-format handling and full unknown-RR serialization are not implemented. |
| [RFC 4592](https://datatracker.ietf.org/doc/html/rfc4592) | Wildcards | Match wildcard records correctly | Not implemented | None | Wildcard lookup is still a placeholder. |
| [RFC 5452](https://datatracker.ietf.org/doc/html/rfc5452) | Forged-answer resilience | Harden recursive answers against poisoning | Partial | Bailiwick validation entry points exist. | `is_subdomain` is still mocked; source-port/ID entropy belongs to the unverified shell or QUIC stack. |
| [RFC 6891](https://datatracker.ietf.org/doc/html/rfc6891) | EDNS0 OPT | OPT pseudo-RR | Partial | Parser tests cover valid additional-section OPT, non-root OPT owner rejection, unsupported EDNS version rejection, truncated option rejection, and unknown option acceptance; padding helper verifies. | OPT option serialization is incomplete. |
| [RFC 7830](https://datatracker.ietf.org/doc/html/rfc7830) | EDNS0 Padding | Padding option for encrypted DNS traffic | Partial | Parser tests cover structurally valid Padding option data and truncation rejection; padding length helper verifies. | Response-side padding serialization is incomplete. |
| [RFC 8467](https://datatracker.ietf.org/doc/html/rfc8467) | EDNS0 padding policy | Block-length padding guidance | Partial | Block padding helper verifies zero block size and remainder behavior. | Policy selection and response-side padding are incomplete. |
| [RFC 8310](https://datatracker.ietf.org/doc/html/rfc8310) | Authentication profiles | Strict/opportunistic authentication profile considerations | Mocked | None | DoQ uses QUIC/TLS; client hello and identity validation are still mocked. |
| [RFC 9250](https://datatracker.ietf.org/doc/html/rfc9250) | DoQ framing | Two-octet length prefix | Partial | Low* stream state verifies complete and split length-prefix parsing, bounded body copying, `ReadingMessage` progress to `Processing`, and conservative overlong-fragment rejection. | Real stream allocation and close/removal semantics are still incomplete. |
| [RFC 9000](https://datatracker.ietf.org/doc/html/rfc9000) | QUIC transport | Streams, connection lifecycle, and flow-control model | Trusted | None | Transport is delegated to EverQuic or an unverified shell adapter. |
| [RFC 9001](https://datatracker.ietf.org/doc/html/rfc9001) | TLS for QUIC | QUIC handshake protection and key schedule | Trusted | None | TLS/QUIC integration is still represented by trusted adapters and mocks. |
| [RFC 9002](https://datatracker.ietf.org/doc/html/rfc9002) | QUIC recovery | Loss detection and congestion control | Trusted | None | Recovery behavior is delegated to EverQuic or the unverified QUIC shell. |
| [RFC 8446](https://datatracker.ietf.org/doc/html/rfc8446) | TLS 1.3 | Authenticated transport | Mocked | None | Mock AEAD and handshake remain. |
| [RFC 8914](https://datatracker.ietf.org/doc/html/rfc8914) | Extended DNS Errors | EDE responses such as Too Early for 0-RTT handling | Not implemented | None | No 0-RTT or EDE response handling exists yet. |
| [RFC 9499](https://datatracker.ietf.org/doc/html/rfc9499) | DNS terminology | Current DNS terms for global DNS, QNAME, bailiwick, and roles | Reference | Documentation alignment only | Use for terminology; no executable behavior is directly required. |

Non-RFC standards dependencies to track separately:
- [draft-ietf-tls-ecdhe-mlkem](https://datatracker.ietf.org/doc/draft-ietf-tls-ecdhe-mlkem/) for hybrid ML-KEM + X25519 TLS 1.3 key agreement until an RFC is published.
- [draft-ietf-tls-mldsa](https://datatracker.ietf.org/doc/draft-ietf-tls-mldsa/) for ML-DSA in TLS 1.3 until an RFC is published.

Extraction status: containerized `make extract` is now a CI smoke gate. It verifies all F*/spec modules first, then extracts the current protocol/security/transport boundary while Phase 3/4 scaffolds remain verification-only.

## 8. Threat Model Summary
- **Spoofing:** Mitigated by TLS 1.3 identity and verified Bailiwick checks.
- **Tampering:** Mitigated by EverCrypt AEAD integrity checks.
- **Information Disclosure:** Mitigated by constant-time crypto and EDNS0 padding.
- **Denial of Service:** Mitigated by Steel-enforced memory bounds and fuel-based recursion limits.
- **Elevation of Privilege:** Mitigated by EverParse-guaranteed memory safety.
- **Harvest Now, Decrypt Later:** Mitigated by Hybrid Post-Quantum Key Exchange.

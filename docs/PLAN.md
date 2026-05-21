# High-Assurance DNS-over-QUIC Server: Implementation Plan

This document outlines the design, architecture, and phased implementation of a mathematically verified DNS-over-QUIC (DoQ) server using F*, Low*, and the Project Everest ecosystem.

## 1. Project Objectives
- **Mathematically Proven Safety:** Eliminate buffer overflows, use-after-free errors, and data races through formal verification.
- **Modern Standards Compliance:** Implement DNS-over-QUIC (RFC 9250) using TLS 1.3 (RFC 8446).
- **Single-Binary Multi-threading:** High-performance execution using a task-based scheduler without relying on process isolation.
- **Parser-Rejecting Security:** Discard malformed or unauthorized packets at the verification boundary before they reach the logic core.
- **Post-Quantum Readiness:** Support for Hybrid Key Exchange (X25519 + ML-KEM) to protect against future quantum adversaries.

## 2. High-Level Architecture

The server follows a "Defensive Ring" architecture, separating the unverified I/O shell from the verified logic core. See [DECISIONS.md](DECISIONS.md) for the accepted architecture and trusted-boundary decisions, and [UNVERIFIED_SHELL.md](UNVERIFIED_SHELL.md) for the shell/core ownership and scheduling contract.

### Architectural Layers
1. **Unverified Shell (C):** Handles POSIX sockets, thread scheduling, maintained QUIC/TLS stack integration, authenticated stream delivery, and the documented buffer-ownership contract.
2. **DoQ Ingress Boundary:** Accepts authenticated QUIC stream bytes from the shell, enforces DoQ length framing, and hands complete DNS messages to parsing.
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
- **Scope:** RFC 1034, RFC 1035, RFC 2181, RFC 3597, RFC 6891, RFC 6895, RFC 7830, RFC 8467, RFC 9267, RFC 9499.
- **Parser Strategy:** The handwritten parser is the bootstrap/reference parser; EverParse remains the production target. See [DECISIONS.md](DECISIONS.md).
- **Equivalence Contract:** The current boundary/reference equivalence contract
  and generated-subset limits are recorded in
  [PARSER_EQUIVALENCE.md](PARSER_EQUIVALENCE.md).
- **Tasks:**
  - Define `DNS_Packet`, `Header`, `Question`, and 43+ `Resource Record` types in F*.
  - Implement bidirectional mapping between F* sum types and IANA numeric constants.
  - Implement recursive `parse_qname` with fuel-based termination to mitigate pointer-loop attacks.
  - Stabilize the handwritten reference parser and tests.
  - Add the minimal response serializer boundary for header, uncompressed names, RR fields, and OPT/Padding responses.
  - Add full-packet serialization with explicit DNS section-count checks.
  - Generate or integrate the EverParse parser/serializer.
  - Compare or migrate away from the handwritten reference parser before declaring Phase 1 production-ready.
- **Verification:** Prove the parser is "total" and "parser-rejecting" for all malformed inputs.

### Phase 2: DoQ Transport and TLS Security
*Goal: Establish verified DoQ stream handling above a maintained QUIC/TLS shell stack.*
- **Scope:** RFC 8310, RFC 8446, RFC 8914, RFC 9000, RFC 9001, RFC 9002, RFC 9250.
- **Sub-phases:**
  - **2A: DNS-over-QUIC framing:** Implement the RFC 9250 two-octet DNS message length prefix, reject malformed frame boundaries, and prove bounds on frame accumulation.
  - **2B: Stream accumulation:** Implement `ReadingLength`, `ReadingMessage`, `Processing`, and cleanup transitions without admitted state changes.
  - **2C: Stream multiplexing:** Implement stream lookup/allocation/close with explicit resource bounds and denial-of-service behavior.
  - **2D: Shell TLS/AEAD contract:** Replace the current trusted AEAD decrypt adapter path with an authenticated stream-byte contract exported by the MsQuic shell stack. Current work adds `DNS.QUIC.MsQuicIngress.handle_authenticated_stream_fragment` as the verified ingress boundary.
  - **2E: Transport lifecycle contract:** Document session teardown, key update, authentication, and forward-secrecy requirements as shell-stack obligations.
  - **2F: MsQuic shell integration:** Wire MsQuic as the preferred maintained QUIC/TLS implementation in the unverified shell, keeping its trust assumptions visible. Current work defines ingress and egress F* handoff boundaries, routes worker response bytes into a caller-provided Low* response buffer before preparing a MsQuic send descriptor, exposes a send-completion/drop cleanup boundary that closes the stream, adds generated C ingress and response handoff/completion ABIs, adds a verified shell-event dispatcher over those boundaries, and adds a fixed-capacity C shell scaffold that owns connection/stream buffers over the generated ABIs; MsQuic wiring, real polling, worker response-construction C ABI coverage, and event queues remain.
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
  - Integrate with the documented [Unverified Shell](UNVERIFIED_SHELL.md) for UDP/QUIC socket I/O.
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

Verification, extraction, C syntax checking, and C link smoke checking are separate gates. Current extraction, `make c-compile-smoke`, and `make c-link-smoke` are generated-artifact smoke tests until the remaining warning-15 debt is acceptable for CI and the shell is linkable. See [DECISIONS.md](DECISIONS.md).

The extraction gate verifies all scaffold modules and sends the current protocol/security/transport boundary plus the authoritative worker and shell-event dispatcher path to KaRaMeL. The clean emitted C/link surface covers the protocol/EverParse parser boundary, `DNS.ShellBoundary.dispatch_authenticated_stream_data`, and `DNS.ShellResponseBoundary` response send handoff/completion. Verification-only parser tests and the broader Phase 3/4 cache/concurrency scaffolds stay out of extraction until they are rewritten into Low* or explicitly marked as trusted/specification-only boundaries.

The C compile smoke gate syntax-checks the current KaRaMeL bundle and the generated EverParse validator/wrapper with the ordinary C compiler. It does not link a runnable shell or claim runtime integration.

The C link smoke gate links and runs a tiny harness against the current extracted protocol bundle, generated EverParse wrapper, shell ingress boundary, response send handoff/completion boundary, and fixed-capacity C shell scaffold. It does not link worker response construction, the shell-event dispatcher, or any MsQuic shell code yet.

The remaining warning-15 debt is concentrated in the protocol model:
- GC-backed list representations in `DNS.Name` and `DNS.Protocol`;
- `dns_packet`, `question`, and `resource_record` records that still carry list-backed fields;
- trusted-adapter boundaries that should stay visible until the generated EverParse or Low* replacement exists.

### F* Release Policy

The stable lane is pinned to F* `v2026.03.24` while old Low* APIs remain in
use. Newer F* releases are tracked in a non-blocking migration lane using
`Containerfile.migration` and the scheduled latest-F* workflow job. Pulse is a
migration evaluation track for stateful transport/shell-boundary code, not a
committed broad rewrite; the parser production path remains EverParse-generated
C. Recent F*, Pulse, and safe Rust extraction are the preferred long-term
migration direction only after an end-to-end migration-lane pilot proves
verification, extraction, FFI ergonomics, generated-code quality, and threat
model compatibility. Promotion gates for moving a Pulse/Rust wrapper into a
checked production boundary are recorded in [DECISIONS.md](DECISIONS.md).

## 6. Parser and Protocol Test Plan

Parser-test policy is recorded in [DECISIONS.md](DECISIONS.md). Initial tests should cover:
- valid single-question DNS query;
- valid single-label DNS query;
- valid two-label DNS query;
- valid three-label DNS query;
- truncated header;
- truncated QNAME;
- invalid label length;
- trailing bytes rejected;
- valid single-answer RR with bounded RDATA preservation;
- truncated RR header and RDATA rejected;
- invalid A/AAAA RDATA lengths rejected;
- valid CNAME RDATA accepted as one fully-consumed uncompressed name;
- truncated, trailing, or compressed name-bearing RDATA rejected;
- valid MX RDATA accepted as preference plus one fully-consumed uncompressed exchange name;
- malformed MX preference or exchange name rejected;
- valid SOA RDATA accepted as two fully-consumed names plus five 32-bit timer fields;
- malformed SOA names, timer tails, or compression pointers rejected;
- valid TXT RDATA accepted as one or more fully-consumed character strings;
- malformed TXT string lengths rejected;
- valid SRV RDATA accepted as priority, weight, port, and one fully-consumed uncompressed target name;
- malformed SRV fixed fields, target names, or compression pointers rejected;
- unknown QTYPE accepted as `UNKNOWN`;
- unknown RR TYPE accepted as `UNKNOWN`;
- valid EDNS0 OPT pseudo-RR accepted in the additional section;
- non-root OPT owner and unsupported EDNS version rejected;
- valid EDNS0 padding option accepted structurally;
- truncated EDNS0 option header and option data rejected;
- unknown EDNS0 option code accepted structurally;
- EDNS0 OPT option and padding bytes serialized and parsed back through the parser;
- DNS header, root question, RR field, and OPT/Padding response bytes serialized and parsed back through the parser;
- full DNS packet serialization rejects section-count mismatches, round-trips question-only packets, and constructs record-bearing packets;
- malformed compression pointers rejected, with RR owner-name pointers to prior names accepted.

These tests should eventually run against both the pure parser and the Low* buffer boundary.

### Future Specification-Validation Evaluation

Evaluate property-based specification validation as a complement to proofs and
parser fixtures before declaring Phase 1 production-ready. The candidate method
is to generate concrete input/output witnesses for pure specifications and test:

- **Admissibility:** the precondition accepts the intended input.
- **Soundness:** the postcondition accepts the intended output.
- **Uniqueness or equivalence:** the postcondition rejects mutated alternative
  outputs, or accepts only outputs related by an explicitly chosen equivalence.

This is intended to detect underspecified contracts, not to replace proofs. The
first evaluation targets should be deterministic, bounded relations where the
specification can be evaluated as a concrete Boolean:

- parser/reference-boundary equivalence for generated EverParse subsets;
- parser and serializer round-trip contracts with mutated parsed records or
  mutated wire bytes;
- zone lookup, wildcard, and CNAME result contracts;
- cache-entry validity for owner, class, TTL, and freshness constraints.

Use mutation-based output generation for likely near-miss witnesses, such as
wrong `rdlen`, wrong RR type, altered compressed pointer targets, extra records,
stale cache entries, or incorrect CNAME chains. Keep any adopted harness
bounded and reproducible so counterexamples can be promoted into ordinary parser
or logic fixtures.

## 7. RFC Compliance Matrix

Maintain a compliance matrix for each protocol area. See [DECISIONS.md](DECISIONS.md).

| RFC | Section | Requirement | Status | Proof/Test Coverage | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [RFC 1034](https://datatracker.ietf.org/doc/html/rfc1034) | DNS concepts | Authoritative data, recursion, CNAME, and wildcard model | Partial | Exact radix lookup, literal `*` wildcard fallback, CNAME target chasing with hop exhaustion, a pure authoritative request-to-`dns_result` adapter, and pure request-to-response packet construction are implemented; CNAME target decoding accepts one fully-consumed uncompressed target name and rejects malformed target RDATA; request adapter tests cover exact answer, wildcard answer, NXDOMAIN, NODATA-style empty success, QCLASS mismatch, empty-question FormErr, first-question handling, and response-packet construction for exact/NODATA/NXDOMAIN/FormErr cases; the zone parser accepts one bootstrap binary zone-entry shape and rejects truncated, trailing, and invalid A/AAAA RDATA-length entries. | Full master-file text parsing, multi-entry zone loading, full RFC 4592 wildcard semantics, complete CNAME/RRset semantics, recursive behavior, and worker response byte dispatch are incomplete. |
| [RFC 1035](https://datatracker.ietf.org/doc/html/rfc1035) | Header format | 12-byte DNS header | Partial | Pure parser tests cover valid and truncated headers; serializer tests cover response header bytes, minimal empty-answer response packet construction, result-to-response packet construction for success/error results, question-only, single-label, two-label, and three-label packet parsing, question-only packet round-trips, and full-packet section-count checks; Low* buffer boundary reads the checked length; shared fixtures now exercise the EverParse production-target subset boundary; a checked-in 3D grammar seed, `make everparse-generate`/`make everparse-verify` targets, containerized EverParse/3D tooling, CI generation of the bounded uncompressed-QNAME question, single-answer RR packet, compressed RR owner-name packets pointing to prior valid message-name offsets, A/AAAA fixed-RDLENGTH answer, NS/CNAME/PTR name-RDATA answer, compressed NS/CNAME/PTR name-RDATA answer pointers resolving to prior valid message-name offsets, MX preference/exchange-name answer, compressed MX exchange-name answer pointers resolving to prior valid message-name offsets, SOA two-name/timer answer, compressed SOA mname/rname answer pointers resolving to prior valid message-name offsets including both-compressed names, SRV priority/weight/port/target-name answer, compressed SRV target-name answer pointers resolving to prior valid message-name offsets, TXT character-string answer, and EDNS0 OPT additional-RR subsets, adapter verification of generated validator symbols, and an active Low* buffer gate through the generated C wrapper for question-only packets with bounded uncompressed QNAMEs plus one-question/one-answer packets with bounded uncompressed names or compressed owner names pointing to prior valid message-name offsets, raw bounded RDATA, generated A/AAAA length checks, generated uncompressed and compressed NS/CNAME/PTR name-RDATA shape checks with compressed pointers resolving to prior valid message-name offsets, generated uncompressed and compressed MX exchange-name shape checks with compressed pointers resolving to prior valid message-name offsets, generated uncompressed and compressed SOA shape checks with compressed pointers resolving to prior valid message-name offsets, generated uncompressed and compressed SRV target-name shape checks with compressed pointers resolving to prior valid message-name offsets, generated TXT shape checks, and generated EDNS0 OPT shape checks define the first external-generation entry point. | External generated validators gate the covered question, single-answer RR, compressed-owner, compressed name-RDATA, compressed MX exchange, compressed SOA name, compressed SRV target, and EDNS0 OPT subsets; full packet construction still uses the handwritten reference parser. |
| [RFC 1035](https://datatracker.ietf.org/doc/html/rfc1035) | QNAME labels | Labels are length-prefixed | Partial | Tests cover valid root QNAMEs, truncated QNAMEs, invalid label length, trailing bytes, accepted compressed RR owner names, CNAME RDATA names, MX exchange names, SOA mname/rname names, and SRV target names pointing to prior question names, and rejected self-loop, forward, out-of-range, and question-name compression pointers. | Compression is accepted for RR owner names, NS/CNAME/PTR RDATA names, MX exchange names, SOA mname/rname names, and SRV target names; question names remain uncompressed for now. |
| [RFC 1035](https://datatracker.ietf.org/doc/html/rfc1035) | Resource records | RR NAME, TYPE, CLASS, TTL, RDLENGTH, and RDATA fields | Partial | Tests cover one answer RR, compressed RR owner-name acceptance, compressed CNAME RDATA-name acceptance, compressed MX exchange-name acceptance, compressed SOA mname/rname acceptance, compressed SRV target-name acceptance, generated-boundary acceptance of the single-answer RR subset, compressed-owner coverage for prior valid message-name offsets, compressed NS/CNAME/PTR RDATA coverage for prior valid message-name offsets, compressed MX exchange-name coverage for prior valid message-name offsets, compressed SOA mname/rname coverage for prior valid message-name offsets including both-compressed names, and compressed SRV target-name coverage for prior valid message-name offsets, generated A/AAAA fixed-RDLENGTH coverage for valid and invalid answer lengths, generated NS/CNAME/PTR uncompressed name-RDATA coverage for valid CNAME and malformed trailing name RDATA, generated MX uncompressed preference/exchange-name coverage for valid and malformed MX RDATA, generated SOA two-name/timer coverage for valid and malformed SOA RDATA, generated SRV uncompressed and compressed priority/weight/port/target-name coverage for valid and malformed SRV RDATA, generated TXT character-string coverage for valid and malformed TXT RDATA, truncated RR headers, truncated RDATA, invalid A/AAAA RDATA lengths, name-bearing CNAME RDATA shape, MX preference/exchange shape, SOA name/timer shape, TXT character-string shape, SRV target shape, minimal RR field serialization, and packet-level construction of record-bearing packets. | RDATA is preserved by RDLENGTH; A/AAAA length validation plus NS/CNAME/PTR/MX/SOA/TXT/SRV shape validation exist, while broader type-specific RDATA validation and generated serializer integration are incomplete. |
| [RFC 2181](https://datatracker.ietf.org/doc/html/rfc2181) | DNS clarifications | RRset, TTL, CNAME, and ranking clarifications | Partial | TTL validity, saturated expiry calculations, and hop-bounded CNAME target following exist. | RRset semantics, trust ranking, and full CNAME rules are incomplete. |
| [RFC 2308](https://datatracker.ietf.org/doc/html/rfc2308) | Negative caching | Cache NXDOMAIN/NODATA and TTL behavior correctly | Partial | Recursive cache lookup checks a conservative first slot for matching owner name and expiry, and insertion writes a saturated-expiry entry to the first slot when capacity is nonzero. | Full cache scanning, replacement/eviction, negative-entry modeling, and sharded concurrency integration are incomplete. |
| [RFC 3597](https://datatracker.ietf.org/doc/html/rfc3597) | Unknown RR types | Preserve unknown types | Partial | Executable parser tests map unknown QTYPE and RR TYPE values to `UNKNOWN`, and RR RDATA is preserved by RDLENGTH. | Presentation-format handling and full unknown-RR serialization are not implemented. |
| [RFC 4592](https://datatracker.ietf.org/doc/html/rfc4592) | Wildcards | Match wildcard records correctly | Partial | In-memory lookup tests cover exact-match precedence, literal `*` fallback, missing-wildcard rejection, no multi-level skipping, root-query behavior, and authoritative request resolution through wildcard answers. | Full closest-encloser semantics, wildcard synthesis rules, and integration with zone loading/worker response generation are incomplete. |
| [RFC 5452](https://datatracker.ietf.org/doc/html/rfc5452) | Forged-answer resilience | Harden recursive answers against poisoning | Partial | Bailiwick validation rejects answer owner names outside the authority-zone suffix, with exact-zone, child-zone, root-zone, sibling-zone, shorter-child, and different-TLD coverage. | Broader recursive resolver validation remains incomplete; source-port/ID entropy belongs to the unverified shell or QUIC stack. |
| [RFC 6891](https://datatracker.ietf.org/doc/html/rfc6891) | EDNS0 OPT | OPT pseudo-RR | Partial | Parser tests cover valid additional-section OPT, non-root OPT owner rejection, unsupported EDNS version rejection, truncated option rejection, unknown option acceptance, basic OPT option serialization round-trips, minimal OPT response serialization, and packet-level OPT construction; generated-boundary tests cover valid OPT, non-root owner rejection, unsupported version rejection, Padding option payloads, unknown option payloads, and truncated option header/data rejection. | Full DNS response generation integration is incomplete. |
| [RFC 6895](https://datatracker.ietf.org/doc/html/rfc6895) | DNS IANA considerations | RR TYPE, CLASS, OpCode, RCODE, and header-bit registry policy | Reference | `qtype` mappings cover assigned RR TYPE constants; `rcode` models assigned response codes; tests preserve unknown QTYPE/RR TYPE values. | BCP 42 registry policy, included to govern numeric constants and allocation ranges rather than runtime packet behavior. Track the 6895bis draft only if it becomes an RFC. |
| [RFC 7830](https://datatracker.ietf.org/doc/html/rfc7830) | EDNS0 Padding | Padding option for encrypted DNS traffic | Partial | Parser tests cover structurally valid Padding option data and truncation rejection; generated-boundary tests cover Padding option payload shape; padding length helper verifies; padding option serialization accounts for the option header and round-trips through the parser. | Response construction does not yet apply padding policy automatically. |
| [RFC 8310](https://datatracker.ietf.org/doc/html/rfc8310) | Authentication profiles | Strict/opportunistic authentication profile considerations | Trusted | ClientHello validation now branches on a trusted TLS adapter result instead of unconditional success. | DoQ uses QUIC/TLS, but identity validation and authentication profile policy are delegated to the MsQuic shell stack. |
| [RFC 8446](https://datatracker.ietf.org/doc/html/rfc8446) | TLS 1.3 | Authenticated transport | Trusted | AEAD decrypt and ClientHello validation now branch on trusted adapter results instead of unconditional success. | TLS handshake, key schedule, certificate policy, and AEAD authenticity are delegated to the MsQuic shell stack. |
| [RFC 8467](https://datatracker.ietf.org/doc/html/rfc8467) | EDNS0 padding policy | Block-length padding guidance | Partial | Block padding helper verifies zero block size and remainder behavior, and padding option serialization handles zero block size. | Policy selection and full response-side integration are incomplete. |
| [RFC 8914](https://datatracker.ietf.org/doc/html/rfc8914) | Extended DNS Errors | EDE responses such as Too Early for 0-RTT handling | Not implemented | None | No 0-RTT or EDE response handling exists yet. |
| [RFC 9000](https://datatracker.ietf.org/doc/html/rfc9000) | QUIC transport | Streams, connection lifecycle, and flow-control model | Trusted | None | Transport is delegated to the MsQuic shell stack. |
| [RFC 9001](https://datatracker.ietf.org/doc/html/rfc9001) | TLS for QUIC | QUIC handshake protection and key schedule | Trusted | None | TLS for QUIC is delegated to the MsQuic shell stack. |
| [RFC 9002](https://datatracker.ietf.org/doc/html/rfc9002) | QUIC recovery | Loss detection and congestion control | Trusted | None | Recovery behavior is delegated to the MsQuic shell stack. |
| [RFC 9250](https://datatracker.ietf.org/doc/html/rfc9250) | DoQ framing | Two-octet length prefix | Partial | Low* stream state verifies complete and split length-prefix parsing, bounded body copying, `ReadingMessage` progress to `Processing` with the completed DNS message length, conservative overlong-fragment rejection, bounded active stream lookup, capacity-bounded stream allocation, compacting active-stream close, worker dispatch through verified stream lookup, worker-side completed-buffer parsing into response bytes, capacity-checked response copy into a caller-provided Low* buffer, worker preparation of a MsQuic send descriptor for that buffer, send-completion/drop cleanup that closes the stream, a verified shell-event dispatcher over authenticated ingress, processing-ready, and send-completion/drop events, an emitted `DNS.ShellBoundary.dispatch_authenticated_stream_data` C ABI for authenticated ingress, emitted `DNS.ShellResponseBoundary` C ABIs for response send handoff/completion, and a fixed-capacity C shell scaffold over those generated ABIs. | Actual MsQuic send-path wiring, worker response-construction/dispatcher C symbols, response-buffer lifetime/aliasing proofs, real polling, event queues, C scheduler integration, and resource-bound proofs remain incomplete. |
| [RFC 9267](https://datatracker.ietf.org/doc/html/rfc9267) | DNS RR processing anti-patterns | Parser hardening guidance for compression pointers, label/name lengths, RDLENGTH, and record counts | Reference | Parser and generated-boundary tests cover pointer loops, out-of-range pointers, label/name bounds, truncated RDATA, and section-count validation. | Informational Independent Submission; use as security review guidance rather than normative protocol behavior. |
| [RFC 9499](https://datatracker.ietf.org/doc/html/rfc9499) | DNS terminology | Current DNS terms for global DNS, QNAME, bailiwick, and roles | Reference | Documentation alignment only | Use for terminology; no executable behavior is directly required. |

Non-RFC standards dependencies to track separately:
- [draft-ietf-tls-ecdhe-mlkem](https://datatracker.ietf.org/doc/draft-ietf-tls-ecdhe-mlkem/) for hybrid ML-KEM + X25519 TLS 1.3 key agreement until an RFC is published.
- [draft-ietf-tls-mldsa](https://datatracker.ietf.org/doc/draft-ietf-tls-mldsa/) for ML-DSA in TLS 1.3 until an RFC is published.

Extraction status: containerized `make extract` is now a CI smoke gate. It verifies all F*/spec modules first, then sends the current protocol/security/transport boundary plus `DNS.Zone.RadixTree`, `DNS.Worker`, `DNS.ShellScheduler`, `DNS.ShellBoundary`, and `DNS.ShellResponseBoundary` to KaRaMeL; broader Phase 3/4 cache/concurrency scaffolds remain verification-only. `make c-compile-smoke` syntax-checks the extracted C bundle and EverParse wrapper, and `make c-link-smoke` links and runs the current emitted protocol/EverParse, shell-ingress, response handoff/completion, and fixed-capacity C shell scaffold without linking a final shell binary.

## 8. Threat Model Summary
- **Spoofing:** Mitigated by TLS 1.3 identity and verified Bailiwick checks.
- **Tampering:** Mitigated by EverCrypt AEAD integrity checks.
- **Information Disclosure:** Mitigated by constant-time crypto and EDNS0 padding.
- **Denial of Service:** Mitigated by Steel-enforced memory bounds and fuel-based recursion limits.
- **Elevation of Privilege:** Mitigated by EverParse-guaranteed memory safety.
- **Harvest Now, Decrypt Later:** Mitigated by Hybrid Post-Quantum Key Exchange.

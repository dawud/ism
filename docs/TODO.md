# Verified DNS-over-QUIC Server TODO List

This roadmap tracks the development of the verified DNS-over-QUIC server in F*, following the five-phase plan.

## Source Audit Status

Last source audit: 2026-05-05.

The repository currently contains F* models and bootstrap skeletons for phases 1-4. The current scaffold verifies, but broad roadmap items should not be read as production-complete while they still rely on `admit()`, `assume`, mock interfaces under `spec/`, or placeholder functions that return fixed values.

Verification was run through the local container image with:

```bash
podman run --rm -v "$(pwd):/workspace:Z" localhost/verified-dns-server:latest
```

The containerized `make verify` command completed successfully and F* reported `All verification conditions discharged successfully`. This proves the current F* obligations as written, but it does not close the admitted, assumed, mocked, or placeholder implementation gaps listed below.

Extraction was also run through the local container image with:

```bash
podman run --rm -v "$(pwd):/workspace:Z" localhost/verified-dns-server:latest \
  bash -lc 'eval $(opam env) && make extract'
```

The containerized `make extract` command now completes and emits C/H files under `dist/`. KaRaMeL still reports many warning-15 diagnostics because significant parts of the scaffold use GC-backed lists, mathematical integers, or specification-oriented definitions that are not Low*. Treat extraction as a generated-artifact smoke test, not yet as proof that the output is production C.

## Status Model

- [x] Verified scaffold: F* accepts the current model/specification as written.
- [/] Implemented with caveats: behavior exists, but still depends on admits, assumptions, mocks, placeholders, or incomplete semantics.
- [ ] Production implementation: real behavior is not implemented yet or is missing its proof.

## Proof Debt / Trusted Gaps

- [ ] Remove all remaining `admit()` calls from recursive cache operations, sharded cache operations, and worker processing.
- [ ] Replace `assume` uses with real refinements or lemmas, especially label casting in `DNS.Name` and `shard_permission` in `DNS.Cache.Sharded`.
- [x] Replace local mock interfaces under `spec/` with real Project Everest / Low* / Steel dependencies or explicitly documented trusted interfaces.
- [ ] Replace placeholder functions that return fixed values, including client hello verification, AEAD decrypt success, zone parsing, wildcard lookup, and bailiwick suffix checks.
- [ ] Add or document the unverified shell boundary for socket/QUIC I/O, buffer ownership transfer, and scheduler/thread integration.
- [/] Run extraction with KaRaMeL after implementation gaps are reduced, not only `make verify`. Current `make extract` completes, but generated C still carries non-Low* warning debt.
- [ ] Keep the trusted-boundary inventory in `docs/THREAT_MODEL.md` current whenever a mock, admission, assumption, or unverified adapter is added or removed.

## Near-Term Technical Work

- [ ] Maintain F* release policy:
  - [x] Keep the stable container pinned to F* `v2026.03.24` while Low* APIs remain in use.
  - [ ] Add a non-blocking latest-F* migration container or CI lane.
  - [ ] Test F* weekly releases in the migration lane on a scheduled cadence.
  - [ ] Decide whether post-Low* migration means Pulse, EverParse-generated C boundaries, or a legacy Low* toolchain.
  - [ ] Promote a newer F* only after verification, extraction strategy, trusted-boundary review, and parser strategy are all clear.
- [x] Remove parser proof debt:
  - [x] Replace `DNS.Name.cast_to_label`'s `assume` with a checked constructor path.
  - [x] Finish `DNS.Name.lemma_parser_rejecting` without `admit()`.
  - [x] Add named safety lemmas for `parse_header_bytes`.
  - [x] Add named safety lemmas for `parse_question_bytes`.
  - [x] Add named safety lemmas for `parse_dns_packet_buffer`.
- [x] Add parser tests:
  - [x] valid single-question DNS query;
  - [x] truncated header;
  - [x] truncated QNAME;
  - [x] invalid label length;
  - [x] trailing bytes rejected;
  - [x] nonzero answer/authority/additional counts rejected until RR parsing lands;
  - [x] unknown QTYPE accepted as `UNKNOWN`;
  - [x] malformed compression pointers rejected until compression support is implemented.
- [/] Add extraction as a routine build gate:
  - [x] run `make extract` in the container;
  - [x] separate extraction blockers from verification blockers;
  - [x] classify and reduce warning-15 non-Low* extraction debt;
  - [x] add extraction to CI once warning debt is understood and acceptable.

  Extraction currently verifies all scaffold modules but only sends the current protocol/security/transport boundary to KaRaMeL. Verification-only parser tests and Phase 3/4 logic/concurrency scaffolds stay out of extraction until they are rewritten into Low* or explicitly marked as trusted/specification-only boundaries.
- [x] Replace local mock specs with real dependencies or documented trusted interfaces:
  - [x] EverCrypt AEAD;
  - [x] EverCrypt cipher/helper interfaces;
  - [x] LowParse/Low* parser interfaces;
  - [x] Steel memory and Steel utility interfaces.
- [x] Make gateway allocation real by replacing the admitted plaintext buffer with verified Low* allocation/copying and explicit size/ownership proofs.
- [x] Maintain the RFC compliance matrix in `docs/PLAN.md` as parser, transport, EDNS0, and TLS work changes status.
- [ ] Execute parser strategy decision:
  - [x] Keep the handwritten F*/Low* parser as the bootstrap/reference parser.
  - [x] Add tests against the handwritten reference parser.
  - [ ] Integrate an EverParse-generated parser/serializer as the production target.
  - [ ] Replace the handwritten parser or document/prove behavioral equivalence before Phase 1 is production-ready.

## Next Technical Milestone

Prioritize Phase 1 parser closure before transport, cache, or worker work:

- [x] Replace `validate_dns_packet = len >= 12` with real DNS wire validation. The obsolete length-only shim was removed; pure byte-list validation uses `parse_dns_packet_bytes`, and the Low* boundary now reads the live plaintext buffer with `read_buffer_range` before parsing.
- [x] Parse DNS header fields from bytes instead of constructing dummy zero headers.
- [x] Parse at least the question section with length-safe QNAME/QTYPE/QCLASS handling.
- [x] Remove the dummy zero-header return from `DNS.Security.Gateway`; successful decrypt now parses the Low* plaintext buffer and returns the parsed packet header.
- [x] Add proof obligations for header and question length safety. The parser is total, rejects short inputs structurally, and has admitted-free named lemmas for header, question, buffer parsing, and flag round-tripping.
- [x] Re-run containerized `make verify` after each parser closure step.

## Phase 1: Formalized Wire Format & Verified Parsing
*Goal: Memory-safe parsing of DNS messages using EverParse.*

- [x] Define basic DNS types (Header, Flags, QType, QName).
- [x] Implement RFC-assigned integer mapping for all 43+ record types.
- [/] Implement `DNS.Protocol.header_validator` and `header_reader` using EverParse. Current code has pure byte-list header parsing, a verified Low* buffer reader, and an `EverParseBoundary` module that delegates to the reference parser; no generated EverParse header reader is present yet.
- [/] Implement recursive `parse_qname` with fuel-based termination for name compression. Current code parses uncompressed labels, enforces the 255-byte DNS name length budget, and rejects compression pointers.
- [/] Implement full `DNS_Packet` parser (Header + Question + RR sections). Current `DNS.Protocol.Parser` parses header and question sections from byte lists, rejects non-empty RR sections, and the gateway no longer returns a dummy zero header.
- [/] **Validation:** Prove parser is "parser-rejecting" for malformed inputs. Current name/header/question/buffer proofs are admitted-free, but broader RR parser obligations remain incomplete because RR parsing is not implemented yet.

## Phase 2: DoQ Transport Layer (QUIC + TLS 1.3)
*Goal: Secure transport tunnel using EverCrypt/EverQuic.*

- [x] Define `crypto_context` for session state.
- [/] Integrate EverCrypt for TLS 1.3 Handshake. Current `DNS.Security.Handshake` defines the state type and transitions, but `verify_client_hello` is a mock that always returns `true`; EverCrypt specs are documented trusted bootstrap adapters.
- [/] Implement `DNS.Security.Gateway` for authenticated decryption and immediate parsing. Current decrypt function always returns `Success`, but the gateway now copies the bounded ciphertext range into a concrete Low* plaintext workspace before parsing it instead of admitting allocation.
- [/] Implement `DNS.QUIC.StreamMapping` state machine (ReadingLength, ReadingMessage). State types exist, the two-byte DoQ length prefix parser reads a bounded Low* buffer, and `handle_stream_data` performs the first complete length-prefix transition. Partial-frame accumulation and message-body copying are not implemented yet.
- [/] Implement Stream ID Multiplexer to handle concurrent streams. `find_stream` performs a verified conservative first-slot lookup with explicit ownership preconditions; `allocate_stream` is an explicit verified no-allocation placeholder; and `close_stream` is an explicit verified no-op placeholder. Real allocation and close/removal semantics are still incomplete.
- [x] Implement EDNS0 (OPT) handling with padding for traffic analysis protection. Current `calculate_padding_len` handles zero block size and computes block padding; OPT parsing/serialization is not implemented.
- [/] **Validation:** Prove query authenticity (decryption success implies integrity). Current code models the boundary but uses mock AEAD success, so authenticity is not proven against real crypto.

## Phase 3: Verified Core Logic & Backend
*Goal: Functional correctness of lookup and response generation.*

- [x] Define `rcode` sum types and `dns_result` core type.
- [/] Implement Verified Static Zone File parser (Master File format). Current `validate_zone_entry` checks A/AAAA RDATA lengths, but `parse_zone_file` is a mock that returns `None`.
- [/] Implement In-Memory Radix Tree for authoritative lookups. Exact lookup is implemented over the in-memory tree; wildcard lookup is a placeholder and tree construction/loading is not implemented.
- [/] Implement CNAME chasing logic with hop-count limits. Hop-count termination exists, but the implementation does not inspect CNAME records or follow CNAME targets.
- [/] Implement Recursive Resolver logic with Bailiwick validation. Current `validate_answer` exists, but `is_subdomain` is mocked and returns `true` for most non-shorter child names instead of proving suffix matching.
- [/] Implement Verified Cache with absolute TTL enforcement. TTL validity and saturated expiry calculation are present, but cache lookup and insertion are admitted.
- [ ] **Validation:** Prove that response generation never leaks cross-thread memory. No complete response generation path or cross-thread memory proof is present.

## Phase 4: Secure Concurrency & I/O Integration
*Goal: Thread-safe execution using Steel.*

- [/] Implement `DNS.Cache.Sharded` using Steel invariants for thread-safe access. Current module defines the sharded cache shape, but `shard_permission` is assumed, shard index is fixed/admitted, and concurrent get/add are admitted.
- [/] Implement the Worker Thread harness (`worker_loop`). Current harness skeleton exists, but it reads the stream context via `admit()`, response processing is admitted, and the loop has no real polling or scheduler integration.
- [ ] Integrate with "Unverified Shell" for UDP/QUIC socket I/O.
- [ ] Implement LRU eviction policy for the concurrent cache. No LRU metadata or eviction path is present.
- [ ] **Validation:** Prove absence of data races using F*'s separation logic.

## Phase 5: Hardening & Supply Chain Verification
*Goal: Production-ready binary and formal audit.*

- [ ] Set up Grammar-Based Fuzzing with EverParse.
- [ ] Implement "Slowloris" protection for QUIC connection management.
- [ ] Configure CompCert for verified C compilation.
- [ ] Implement Post-Quantum Cryptography (PQC) Transition:
    - [ ] Hybrid ML-KEM + X25519 Key Exchange.
    - [ ] ML-DSA (Dilithium) Signature verification for CA.
- [ ] **Validation:** Run F* solver for final verification of all functional correctness proofs.

---
## Legend
- [ ] Not Started
- [/] In Progress
- [x] Completed

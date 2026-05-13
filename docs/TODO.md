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

- [ ] Remove all remaining `admit()` calls from sharded cache operations and worker processing.
- [ ] Replace `assume` uses with real refinements or lemmas, especially label casting in `DNS.Name` and `shard_permission` in `DNS.Cache.Sharded`.
- [x] Replace local mock interfaces under `spec/` with real Project Everest / Low* / Steel dependencies or explicitly documented trusted interfaces.
- [ ] Replace placeholder functions that return fixed values, including client hello verification and AEAD decrypt success.
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
  - [x] valid single-label DNS query;
  - [x] valid two-label DNS query;
  - [x] valid three-label DNS query;
  - [x] truncated header;
  - [x] truncated QNAME;
  - [x] invalid label length;
  - [x] trailing bytes rejected;
  - [x] truncated RR sections rejected;
  - [x] unknown QTYPE accepted as `UNKNOWN`;
  - [x] single-answer RR accepted with bounded RDATA preservation;
  - [x] truncated RR header and RDATA rejected;
  - [x] invalid A/AAAA RDATA lengths rejected;
  - [x] unknown RR TYPE accepted as `UNKNOWN`;
  - [x] EDNS0 OPT pseudo-RR accepted in the additional section with root owner and version 0;
  - [x] non-root OPT owner and unsupported EDNS version rejected;
  - [x] EDNS0 option headers and bounded option data parsed structurally;
  - [x] truncated EDNS0 option headers and option data rejected;
  - [x] EDNS0 padding and unknown option codes accepted structurally;
  - [x] EDNS0 OPT option and padding bytes serialized with parser round-trip coverage;
  - [x] DNS header, root question, RR field, and OPT/Padding response bytes serialized with parser round-trip coverage;
  - [x] full DNS packet byte serialization rejects section-count mismatches, round-trips question-only packets, and constructs record-bearing packets;
  - [x] NS/CNAME/PTR RDATA accepted only when it is a single fully-consumed uncompressed domain name;
  - [x] MX RDATA accepted only when it has a two-byte preference and a single fully-consumed uncompressed exchange name;
  - [x] SOA RDATA accepted only when it has two fully-consumed domain names plus five 32-bit timer fields;
  - [x] TXT RDATA accepted only when it contains one or more fully-consumed character strings;
  - [x] SRV RDATA accepted only when it has priority, weight, port, and a single fully-consumed uncompressed target name;
  - [x] malformed compression pointers rejected; RR owner-name pointers to prior names accepted.
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
  - [/] Integrate an EverParse-generated parser/serializer as the production target. Current work adds a production-target boundary candidate for the implemented header/question/RR subset, runs the shared parser fixtures through that boundary, checks in a 3D grammar seed for bounded uncompressed-QNAME question validation, a single-answer RR packet subset, A/AAAA fixed-RDLENGTH answer subsets, NS/CNAME/PTR name-RDATA answer subsets, an MX preference/exchange-name answer subset, an SOA two-name/timer answer subset, an SRV priority/weight/port/target-name answer subset, and a TXT character-string answer subset, adds explicit `make everparse-generate` and `make everparse-verify` targets, installs EverParse/3D tooling in the pinned container, runs generated subset verification in CI, removes the local LowParse shim, verifies an adapter that imports the generated validator symbols, and gates the active Low* buffer parser through the generated C wrapper for question-only packets with bounded uncompressed QNAMEs plus one-question/one-answer packets with bounded uncompressed names, raw bounded RDATA, generated A/AAAA length checks, generated name-RDATA shape checks, generated MX shape checks, generated SOA shape checks, generated SRV shape checks, and generated TXT shape checks; full packet construction still uses the handwritten reference parser.
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
- [/] Implement `DNS.Protocol.header_validator` and `header_reader` using EverParse. Current code has pure byte-list header/RR parsing, minimal full-packet byte serialization for uncompressed names/raw RDATA, a verified Low* buffer reader, an `EverParseBoundary` module that routes through a production-target subset boundary matching the reference parser, a checked-in 3D grammar seed plus generator/verification targets for bounded uncompressed-QNAME question validation, a single-answer RR packet subset, A/AAAA fixed-RDLENGTH answer subsets, NS/CNAME/PTR name-RDATA answer subsets, an MX preference/exchange-name answer subset, an SOA two-name/timer answer subset, an SRV priority/weight/port/target-name answer subset, and a TXT character-string answer subset, containerized EverParse/3D tooling, CI generation of the subset artifact, no local LowParse shim, an EverParse-verified adapter that imports the generated validator symbols, and an active Low* buffer gate through the generated C wrapper for question-only packets with bounded uncompressed QNAMEs plus one-question/one-answer packets with bounded uncompressed names, raw bounded RDATA, generated A/AAAA length checks, generated name-RDATA shape checks, generated MX shape checks, generated SOA shape checks, generated SRV shape checks, and generated TXT shape checks; full packet construction still uses the handwritten reference parser.
- [/] Implement recursive `parse_qname` with fuel-based termination for name compression. Current code parses uncompressed question names, enforces the 255-byte DNS name length budget, accepts RR owner-name, NS/CNAME/PTR RDATA-name, MX exchange-name, SOA mname/rname, and SRV target-name compression pointers to prior message offsets, and rejects self-loop, forward, out-of-range, and question-name compression pointers.
- [/] Implement full `DNS_Packet` parser (Header + Question + RR sections). Current `DNS.Protocol.Parser` parses header, question, and RR sections from byte lists; RR parsing preserves bounded RDATA bytes, maps unknown types to `UNKNOWN`, validates A/AAAA RDATA lengths, validates NS/CNAME/PTR/MX/SOA/TXT/SRV RDATA shapes, accepts compressed RR owner names, NS/CNAME/PTR RDATA names, MX exchange names, SOA mname/rname names, and SRV target names pointing to prior names, and accepts structurally valid EDNS0 OPT pseudo-RRs/options in the additional section, but broader type-specific RDATA validation is not implemented yet.
- [/] **Validation:** Prove parser is "parser-rejecting" for malformed inputs. Current name/header/question/buffer proofs are admitted-free, and tests cover RR truncation, A/AAAA RDATA length rejection, name-bearing, MX, SOA, TXT, and SRV RDATA rejection cases, malformed OPT rejection, malformed EDNS option rejection, valid compressed RR owner names, valid compressed CNAME RDATA names, valid compressed MX exchange names, valid compressed SOA mname/rname names, valid compressed SRV target names, and malformed RR owner/RDATA-name compression pointers; broader type-specific RR parser obligations remain incomplete.

## Phase 2: DoQ Transport Layer (QUIC + TLS 1.3)
*Goal: Secure transport tunnel using EverCrypt/EverQuic.*

- [x] Define `crypto_context` for session state.
- [/] Integrate EverCrypt for TLS 1.3 Handshake. Current `DNS.Security.Handshake` defines the state type and transitions, but `verify_client_hello` is a mock that always returns `true`; EverCrypt specs are documented trusted bootstrap adapters.
- [/] Implement `DNS.Security.Gateway` for authenticated decryption and immediate parsing. Current decrypt function always returns `Success`, but the gateway now copies the bounded ciphertext range into a concrete Low* plaintext workspace before parsing it instead of admitting allocation.
- [/] Implement `DNS.QUIC.StreamMapping` state machine (ReadingLength, ReadingMessage). State types exist, the two-byte DoQ length prefix parser reads a bounded Low* buffer, `handle_stream_data` copies bounded body bytes into the stream buffer, persists stream phase updates, stores a one-byte partial length prefix, accounts for body bytes after a completed length prefix, advances `ReadingMessage` to `Processing` once enough bytes arrive, and transitions to `Done` for overlong body fragments. Real allocation and close/removal semantics are still incomplete.
- [/] Implement Stream ID Multiplexer to handle concurrent streams. `find_stream` performs a verified conservative first-slot lookup with explicit ownership preconditions; `allocate_stream` is an explicit verified no-allocation placeholder; and `close_stream` is an explicit verified no-op placeholder. Real allocation and close/removal semantics are still incomplete.
- [x] Implement EDNS0 (OPT) handling with padding for traffic analysis protection. Current `calculate_padding_len` handles zero block size and computes block padding, structural OPT parsing accepts version 0 in the additional section and structurally parses bounded EDNS options, and basic OPT option/padding response serialization round-trips through the parser. Full response-policy integration is not implemented.
- [/] **Validation:** Prove query authenticity (decryption success implies integrity). Current code models the boundary but uses mock AEAD success, so authenticity is not proven against real crypto.

## Phase 3: Verified Core Logic & Backend
*Goal: Functional correctness of lookup and response generation.*

- [x] Define `rcode` sum types and `dns_result` core type.
- [/] Implement Verified Static Zone File parser (Master File format). Current code parses one bootstrap binary zone-entry shape with origin QNAME, TTL, CLASS, TYPE, RDLENGTH, and exact RDATA bytes; validates A/AAAA RDLENGTH; and rejects truncated, trailing, and invalid A/AAAA entries. Full master-file text parsing and multi-entry iteration are incomplete.
- [/] Implement In-Memory Radix Tree for authoritative lookups. Exact lookup and literal `*` wildcard fallback are implemented over the in-memory tree; tree construction/loading is not implemented.
- [/] Implement CNAME chasing logic with hop-count limits. Current code inspects CNAME records, decodes uncompressed target names from RDATA, follows targets with the existing hop bound, returns `ServFail` on malformed CNAME targets or hop exhaustion, and returns `NXDomain` when a followed target is absent; broader CNAME/RRset semantics remain incomplete.
- [/] Implement Recursive Resolver logic with Bailiwick validation. Current `validate_answer` rejects records whose owner name is not under the authority zone using a verified DNS-name suffix check; broader recursive answer validation remains incomplete.
- [/] Implement Verified Cache with absolute TTL enforcement. TTL validity, saturated expiry calculation, and conservative first-slot lookup/insertion are present; full bounded scanning, eviction, and replacement policy are incomplete.
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

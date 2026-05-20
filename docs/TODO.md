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

The containerized `make extract` command now completes and emits C/H files under `dist/`, `make c-compile-smoke` syntax-checks the current extracted C bundle plus the EverParse wrapper, and `make c-link-smoke` links and runs a tiny generated-boundary smoke binary covering the parser wrapper, `DNS.ShellBoundary` ingress ABI, `DNS.ShellResponseBoundary` response send handoff/completion ABI, and the fixed-capacity C shell scaffold. KaRaMeL still reports many warning-15 diagnostics because significant parts of the scaffold use GC-backed lists, mathematical integers, or specification-oriented definitions that are not Low*. Treat extraction/compile/link checks as generated-artifact smoke tests, not yet as proof that the output is production-linked C.

## Status Model

- [x] Verified scaffold: F* accepts the current model/specification as written.
- [/] Implemented with caveats: behavior exists, but still depends on admits, assumptions, mocks, placeholders, or incomplete semantics.
- [ ] Production implementation: real behavior is not implemented yet or is missing its proof.

## Proof Debt / Trusted Gaps

- [x] Remove all remaining `admit()` calls from worker processing.
- [x] Replace `assume` uses with real refinements or lemmas.
- [x] Replace local mock interfaces under `spec/` with real Project Everest / Low* / Steel dependencies or explicitly documented trusted interfaces.
- [x] Replace placeholder functions that return fixed values. Client hello validation and AEAD decrypt now branch on trusted adapter results, but the accepted architecture delegates real QUIC/TLS to a maintained unverified shell stack, with MsQuic preferred.
- [x] Add or document the unverified shell boundary for socket/QUIC I/O, buffer ownership transfer, and scheduler/thread integration. See [UNVERIFIED_SHELL.md](UNVERIFIED_SHELL.md).
- [/] Run extraction with KaRaMeL after implementation gaps are reduced, not only `make verify`. Current `make extract` completes, but generated C still carries non-Low* warning debt.
- [ ] Keep the trusted-boundary inventory in `docs/THREAT_MODEL.md` current whenever a mock, admission, assumption, or unverified adapter is added or removed.

## Near-Term Technical Work

- [ ] Maintain F* release policy:
  - [x] Keep the stable container pinned to F* `v2026.03.24` while Low* APIs remain in use.
  - [x] Add a non-blocking latest-F* migration container or CI lane.
  - [x] Test F* weekly releases in the migration lane on a scheduled cadence.
  - [x] Decide whether post-Low* migration means Pulse, EverParse-generated C boundaries, or a legacy Low* toolchain. See [DECISIONS.md](DECISIONS.md): Pulse is an evaluation track, EverParse remains the parser production path, and legacy Low*/KaRaMeL stays pinned until a migration lane proves a replacement.
  - [/] Prototype a small transport or shell-boundary module in Pulse in the non-blocking migration lane. Current work adds `migration/DNS.Migration.PulseShellBoundary.fst`, a minimal authenticated stream-byte capacity transition over a Pulse-owned `ref`, and verifies it through the migration-only `make verify-pulse-pilot` target before the broader latest-F* compatibility check.
  - [/] Extract the Pulse pilot to safe Rust and assess generated-code quality, FFI shape, dependency surface, and threat-model impact. Current work adds `make assess-pulse-pilot-rust`, which verifies and emits Pulse pilot `.krml` artifacts, then attempts Rust translation. The ref-based pilot is blocked because the generated code references `Pulse.Lib.Reference.op_Bang`, which KaRaMeL reports has no corresponding runtime implementation. A value-state pilot using `FStar.UInt32.t` translates to safe Rust when the unused `C` support module is dropped from the Rust backend pass.
  - [x] Investigate whether Pulse Rust extraction should use a supported reference runtime, a different Pulse state representation, or a narrow trusted Rust/C adapter for mutable shell-boundary state. Current evidence favors extraction-supported value-state APIs for shell-boundary data passed over FFI, while Pulse references remain useful for proofs until runtime support is proven.
  - [/] Extend the value-state Pulse pilot into an FFI-shaped shell-boundary API and assess generated Rust compile/link behavior. Current work adds `make pulse-rust-smoke`, which compiles and runs a tiny Rust program against the generated value-state Pulse module in the migration container, then builds an extern-friendly Rust `staticlib` wrapper and links it from a C smoke caller.
  - [x] Add extern-friendly generated Rust wrappers and document the ABI shape needed by the unverified shell.
  - [x] Define promotion gates for moving Pulse/Rust wrappers from migration evidence to checked production boundaries.
  - [ ] Promote the Pulse/Rust wrapper from migration smoke artifact to a checked production boundary only after the shell ABI, ownership model, and promotion criteria are settled.
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
  - [x] syntax-check the generated C bundle and EverParse wrapper with `make c-compile-smoke`;
  - [x] link and run the current generated protocol/EverParse and shell-boundary smoke binary with `make c-link-smoke`;
  - [x] separate extraction blockers from verification blockers;
  - [x] classify and reduce warning-15 non-Low* extraction debt;
  - [x] add extraction to CI once warning debt is understood and acceptable.

  Extraction currently verifies all scaffold modules and sends the current protocol/security/transport boundary plus the authoritative worker and shell-event dispatcher path to KaRaMeL. The clean emitted C/link surface covers the protocol/EverParse parser boundary, `DNS.ShellBoundary.dispatch_authenticated_stream_data`, `DNS.ShellResponseBoundary` response send handoff/completion, and a fixed-capacity C shell scaffold over those generated ABIs. Broader worker response construction, dispatcher integration, MsQuic polling, and Phase 3/4 cache/concurrency scaffolds stay out of the linked smoke surface until they are rewritten into Low* or explicitly marked as trusted/specification-only boundaries.
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
  - [/] Integrate an EverParse-generated parser/serializer as the production target. Current work adds a production-target boundary candidate for the implemented header/question/RR subset, runs the shared parser fixtures through that boundary, checks in a 3D grammar seed for bounded uncompressed-QNAME question validation, a single-answer RR packet subset, A/AAAA fixed-RDLENGTH answer subsets, NS/CNAME/PTR name-RDATA answer subsets, an MX preference/exchange-name answer subset, an SOA two-name/timer answer subset, an SRV priority/weight/port/target-name answer subset, a TXT character-string answer subset, an EDNS0 OPT additional-RR subset with version-0 and bounded option header/data checks, a compressed RR owner-name subset for prior valid message-name offsets, a compressed NS/CNAME/PTR RDATA subset for prior valid message-name offsets, a compressed MX exchange-name subset for the same `0xc00c` pointer, compressed SOA mname/rname subsets for the same `0xc00c` pointer, and a compressed SRV target-name subset for the same `0xc00c` pointer, adds explicit `make everparse-generate` and `make everparse-verify` targets, installs EverParse/3D tooling in the pinned container, runs generated subset verification in CI, removes the local LowParse shim, verifies an adapter that imports the generated validator symbols, and gates the active Low* buffer parser through the generated C wrapper for question-only packets with bounded uncompressed QNAMEs plus one-question/one-answer packets with bounded uncompressed names, one-question/one-answer packets with compressed owner names pointing to prior valid message-name offsets, raw bounded RDATA, generated A/AAAA length checks, generated uncompressed and compressed NS/CNAME/PTR name-RDATA shape checks with compressed pointers resolving to prior valid message-name offsets, generated uncompressed and compressed `0xc00c` MX shape checks, generated uncompressed and compressed `0xc00c` SOA shape checks, generated uncompressed and compressed `0xc00c` SRV shape checks, generated TXT shape checks, and generated EDNS0 OPT shape checks; full packet construction still uses the handwritten reference parser.
  - [x] Extend the generated boundary to cover EDNS0 OPT additional records with bounded option headers/data.
  - [x] Extend the generated boundary to cover compressed RR owner-name pointers to prior valid message-name offsets.
  - [x] Extend the generated boundary to cover common compressed NS/CNAME/PTR RDATA pointers to the question name.
  - [x] Extend the generated boundary to cover compressed NS/CNAME/PTR RDATA pointers to prior valid message-name offsets.
  - [x] Extend the generated boundary to cover common compressed MX exchange-name pointers to the question name.
  - [x] Extend the generated boundary to cover common compressed SOA mname/rname pointers to the question name when the other SOA name is uncompressed.
  - [x] Extend the generated boundary to cover both common compressed SOA mname/rname pointers to the question name.
  - [x] Extend the generated boundary to cover common compressed SRV target-name pointers to the question name.
  - [x] Document the boundary/reference equivalence contract and generated-subset limits in [PARSER_EQUIVALENCE.md](PARSER_EQUIVALENCE.md).
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
- [/] Implement `DNS.Protocol.header_validator` and `header_reader` using EverParse. Current code has pure byte-list header/RR parsing, minimal full-packet byte serialization for uncompressed names/raw RDATA, a verified Low* buffer reader, an `EverParseBoundary` module that routes through a production-target subset boundary matching the reference parser, a checked-in 3D grammar seed plus generator/verification targets for bounded uncompressed-QNAME question validation, a single-answer RR packet subset, A/AAAA fixed-RDLENGTH answer subsets, NS/CNAME/PTR name-RDATA answer subsets, an MX preference/exchange-name answer subset, an SOA two-name/timer answer subset, an SRV priority/weight/port/target-name answer subset, a TXT character-string answer subset, an EDNS0 OPT additional-RR subset, a compressed RR owner-name subset for prior valid message-name offsets, a compressed NS/CNAME/PTR RDATA subset for prior valid message-name offsets, a compressed MX exchange-name `0xc00c` subset, compressed SOA mname/rname `0xc00c` subsets, and a compressed SRV target-name `0xc00c` subset, containerized EverParse/3D tooling, CI generation of the subset artifact, no local LowParse shim, an EverParse-verified adapter that imports the generated validator symbols, and an active Low* buffer gate through the generated C wrapper for question-only packets with bounded uncompressed QNAMEs plus one-question/one-answer packets with bounded uncompressed names or compressed owner names pointing to prior valid message-name offsets, raw bounded RDATA, generated A/AAAA length checks, generated uncompressed and compressed NS/CNAME/PTR name-RDATA shape checks with compressed pointers resolving to prior valid message-name offsets, generated uncompressed and compressed `0xc00c` MX shape checks, generated uncompressed and compressed `0xc00c` SOA shape checks, generated uncompressed and compressed `0xc00c` SRV shape checks, generated TXT shape checks, and generated EDNS0 OPT version/option-shape checks; full packet construction still uses the handwritten reference parser.
- [/] Implement recursive `parse_qname` with fuel-based termination for name compression. Current code parses uncompressed question names, enforces the 255-byte DNS name length budget, accepts RR owner-name, NS/CNAME/PTR RDATA-name, MX exchange-name, SOA mname/rname, and SRV target-name compression pointers to prior message offsets, and rejects self-loop, forward, out-of-range, and question-name compression pointers.
- [/] Implement full `DNS_Packet` parser (Header + Question + RR sections). Current `DNS.Protocol.Parser` parses header, question, and RR sections from byte lists; RR parsing preserves bounded RDATA bytes, maps unknown types to `UNKNOWN`, validates A/AAAA RDATA lengths, validates NS/CNAME/PTR/MX/SOA/TXT/SRV RDATA shapes, accepts compressed RR owner names, NS/CNAME/PTR RDATA names, MX exchange names, SOA mname/rname names, and SRV target names pointing to prior names, and accepts structurally valid EDNS0 OPT pseudo-RRs/options in the additional section, but broader type-specific RDATA validation is not implemented yet.
- [/] **Validation:** Prove parser is "parser-rejecting" for malformed inputs. Current name/header/question/buffer proofs are admitted-free, and tests cover RR truncation, A/AAAA RDATA length rejection, name-bearing, MX, SOA, TXT, SRV, and generated EDNS0 OPT rejection cases, malformed OPT rejection, malformed EDNS option rejection, valid compressed RR owner names, valid compressed CNAME RDATA names including generated prior-offset coverage, valid compressed MX exchange names including generated `0xc00c` coverage, valid compressed SOA mname/rname names including generated `0xc00c` coverage, valid compressed SRV target names including generated `0xc00c` coverage, and malformed RR owner/RDATA-name compression pointers; broader type-specific RR parser obligations remain incomplete.

## Phase 2: DoQ Transport Layer (QUIC + TLS 1.3)
*Goal: Verified DoQ stream handling above a maintained unverified QUIC/TLS shell stack.*

- [x] Define `crypto_context` for session state.
- [/] Delegate TLS 1.3 handshake and authentication policy to the MsQuic shell stack. Current `DNS.Security.Handshake` defines the state type and transitions, but `verify_client_hello` still delegates success/failure to the trusted `EverCrypt.Cipher.validate_client_hello` bootstrap adapter until the shell boundary bypasses it.
- [/] Replace `DNS.Security.Gateway` authenticated decryption with authenticated stream-byte ingress from the MsQuic shell stack. Current decrypt delegates success/failure to the trusted `EverCrypt.AEAD.decrypt_authenticated` bootstrap adapter, and the gateway copies the bounded ciphertext range into a concrete Low* plaintext workspace before parsing it instead of admitting allocation; `DNS.QUIC.MsQuicIngress.handle_authenticated_stream_fragment` is now the preferred verified ingress boundary for authenticated MsQuic stream bytes.
- [/] Implement `DNS.QUIC.StreamMapping` state machine (ReadingLength, ReadingMessage). State types exist, the two-byte DoQ length prefix parser reads a bounded Low* buffer, `handle_stream_data` copies bounded body bytes into the stream buffer, persists stream phase updates, stores a one-byte partial length prefix, accounts for body bytes after a completed length prefix, advances `ReadingMessage` to `Processing` with the completed DNS message length once enough bytes arrive, and transitions to `Done` for overlong body fragments. Resource-bound proofs remain incomplete.
- [/] Implement Stream ID Multiplexer to handle concurrent streams. `find_stream` performs a verified bounded scan over active stream slots with explicit ownership preconditions; `allocate_stream` uses the connection capacity to initialize the next active slot and increment the active count; and `close_stream` scans the active prefix, compacts the table by moving the last active stream pointer into the removed slot, and decrements the active count. Broader stream lifecycle integration and resource-bound proofs remain incomplete.
- [x] Implement EDNS0 (OPT) handling with padding for traffic analysis protection. Current `calculate_padding_len` handles zero block size and computes block padding, structural OPT parsing accepts version 0 in the additional section and structurally parses bounded EDNS options, and basic OPT option/padding response serialization round-trips through the parser. Full response-policy integration is not implemented.
- [/] **Validation:** Prove the verified core only processes authenticated stream bytes. Current code models the boundary through a trusted AEAD adapter result; the accepted architecture moves authenticity to the MsQuic shell stack, and `DNS.QUIC.MsQuicIngress` defines the explicit shell/core ingress contract. Remaining work is to wire the C shell to that contract and bypass the legacy decrypt/client-hello adapters.

## Phase 3: Verified Core Logic & Backend
*Goal: Functional correctness of lookup and response generation.*

- [x] Define `rcode` sum types and `dns_result` core type.
- [/] Implement Verified Static Zone File parser (Master File format). Current code parses one bootstrap binary zone-entry shape with origin QNAME, TTL, CLASS, TYPE, RDLENGTH, and exact RDATA bytes; validates A/AAAA RDLENGTH; and rejects truncated, trailing, and invalid A/AAAA entries. Full master-file text parsing and multi-entry iteration are incomplete.
- [/] Implement In-Memory Radix Tree for authoritative lookups. Exact lookup, literal `*` wildcard fallback, and a pure authoritative request adapter are implemented over the in-memory tree; tree construction/loading is not implemented.
- [/] Implement CNAME chasing logic with hop-count limits. Current code inspects CNAME records, decodes uncompressed target names from RDATA, follows targets with the existing hop bound through the authoritative request adapter, returns `ServFail` on malformed CNAME targets or hop exhaustion, and returns `NXDomain` when a followed target is absent; broader CNAME/RRset semantics remain incomplete.
- [/] Implement Recursive Resolver logic with Bailiwick validation. Current `validate_answer` rejects records whose owner name is not under the authority zone using a verified DNS-name suffix check; broader recursive answer validation remains incomplete.
- [/] Implement Verified Cache with absolute TTL enforcement. TTL validity, saturated expiry calculation, and conservative first-slot lookup/insertion are present; full bounded scanning, eviction, and replacement policy are incomplete.
- [/] **Validation:** Prove that response generation never leaks cross-thread memory. A pure authoritative response adapter now maps parsed requests through lookup/CNAME resolution into response packets, the response packet builder echoes request questions, maps success records to the answer section, maps error results to empty-answer responses with the selected RCODE, and the worker `Processing` branch parses completed stream buffers, builds response bytes, copies them into a caller-provided Low* response buffer with an explicit capacity check, and prepares a MsQuic send descriptor for that buffer. `DNS.QUIC.MsQuicSendCompletion.complete_response_send` models close cleanup after the shell completes or drops the send. Cross-thread buffer lifetime and aliasing proofs are not present.

## Phase 4: Secure Concurrency & I/O Integration
*Goal: Thread-safe execution using Steel.*

- [/] Implement `DNS.Cache.Sharded` using Steel invariants for thread-safe access. Current module defines the sharded cache shape, `shard_permission` is a concrete erased `vprop` placeholder through the trusted Steel bootstrap adapter, and concurrent get/add conservatively delegate to the first shard with explicit ownership preconditions. Real hash-based shard selection and Steel invariants are still incomplete.
- [/] Implement the Worker Thread harness (`worker_loop`). Current harness uses verified stream lookup, reads a matching active stream context, parses completed `Processing` stream buffers into response bytes, copies the serialized response into a caller-provided Low* response buffer, prepares a MsQuic send descriptor without admits, exposes a verified send-completion/drop cleanup boundary that closes the stream, routes shell-selected events through `DNS.ShellScheduler.dispatch_shell_event`, includes the worker/dispatcher path in the KaRaMeL extraction smoke gate, exposes a generated C ingress ABI through `DNS.ShellBoundary.dispatch_authenticated_stream_data`, exposes `DNS.ShellResponseBoundary` C symbols for response send handoff/completion, and has a fixed-capacity C shell scaffold that owns connection/stream buffers and calls those generated ABIs. Real polling, event queues, worker response-construction C ABI coverage, and C/MsQuic scheduler integration remain incomplete.
- [/] Integrate with the documented [Unverified Shell](UNVERIFIED_SHELL.md) for UDP/QUIC socket I/O. Current work adds `shell/ism_shell.c` as a fixed-capacity shell-owned buffer and stream-context scaffold over the generated ingress/egress ABIs, but it does not link MsQuic, sockets, polling, timers, or production allocation yet.
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

# Verified DNS-over-QUIC Server TODO List

This roadmap tracks the development of the verified DNS-over-QUIC server in F*, following the five-phase plan.

## Source Audit Status

Last source audit: 2026-09-11; remediation evidence updated: 2026-09-17.

The audit remediation is tracked in [PROOF_AUDIT_ACTIONS.md](PROOF_AUDIT_ACTIONS.md).
Passing gates establish only their written component contracts. In particular,
external C-validator acceptance equivalence, full DNS semantics, real concurrency
ownership, and production worker extraction/integration remain separate gates.

The repository contains F* models and bootstrap skeletons for phases 1-4. The
September source scan found no explicit project `admit`, `assume`, or `magic`.
Abstract interfaces under `spec/`, weak contracts, and fixed-value placeholders
still prevent interpreting passing verification as production completeness.

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

The containerized `make extract` command now completes and emits C/H files under `dist/`, `make c-compile-smoke` syntax-checks the current extracted C bundle plus the EverParse wrapper, `make c-link-smoke` links and runs a tiny generated-boundary smoke binary covering the parser wrapper, `DNS.ShellBoundary` ingress, minimal worker FORMERR, header-only empty NOERROR, generated-validator-backed question-echo response ABIs, DoQ egress response framing, C-shaped scheduler helper ABIs for ingress/minimal worker/send-completion events, `DNS.ShellResponseBoundary` response send handoff/completion ABI, the fixed-capacity C shell scaffold, the MsQuic-shaped adapter smoke path with validated question-echo and FORMERR cases, and a fixed-capacity shell event queue smoke path with synchronous ready-response service for completed ingress, `make msquic-runtime-compile-smoke` checks the real `QUIC_STREAM_EVENT`, `QUIC_CONNECTION_EVENT`, and `QUIC_LISTENER_EVENT` callback seams against a pinned upstream `msquic.h` header in the stable container, `make msquic-runtime-connection-smoke` links/runs a fake-API behavior check for listener new-connection handling, peer-started stream mapping, real `StreamSend` submission/completion, shutdown cleanup, and rejected-stream closure, `make msquic-runtime-link-smoke` links/runs a no-network MsQuic API-table open/close check, `make msquic-runtime-lifecycle-smoke` opens/closes no-network registration, configuration, and listener handles, `make msquic-runtime-listener-smoke` starts/stops a loopback listener on an ephemeral local port, and `make msquic-runtime-stream-smoke` runs a live loopback client/server stream exchange with test-only credentials through the real receive/send callback boundary. Recent warning cleanup moved response-handoff, scheduler send-completion, minimal worker response construction, shell/scheduler minimal-worker dispatch, stream lookup/close, stream accumulation state transitions/copy lengths, and the DoQ length-prefix byte widening helper to machine-integer-friendly code. The C-linked shell bundle now uses `DNS.Worker.Minimal` and no longer extracts the full list-backed worker/zone response path. KaRaMeL still reports warning-15 diagnostics because significant parts of the protocol model use GC-backed lists or specification-oriented definitions that are not Low*. Treat extraction/compile/link checks as generated-artifact smoke tests, not yet as proof that the output is a production-linked server.

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

### Pulse-to-C migration and toolchain update

Accepted plan: DR-0017, 2026-09-18. Follow the ordered M1–M5 milestones in
[PLAN.md](PLAN.md#cross-cutting-pulse-migration-and-toolchain-update).
The implementation target is Pulse → KaRaMeL → C, retaining EverParse and the
C/MsQuic shell. Rust is not on this migration's critical path.

- [x] Retain the stable F* `v2026.03.24` baseline and a separate scheduled,
  non-blocking latest-F* exploration lane.
- [x] Evaluate the existing pilots on F* `v2026.09.13`. Both verify; the
  value-only Rust/C smoke passes, but the pilot omits the real DoQ lifecycle
  and is not a verified/integrated replacement. The original full legacy build
  failed on the multi-file invocation and removed HyperStack APIs. After fixing
  invocation, the first full-build incompatibility is `Prims.op_Addition` in
  `DNS.Name`; removed HyperStack remains another known porting dependency.
- [x] **M1: Candidate lane.** F* `v2026.09.13` bundle checksum, bundled KaRaMeL
  and solver identities pinned; Z3 4.13.3 selected explicitly. EverParse pin
  recorded separately, actual C/OS toolchain recorded in provenance. Added
  isolated candidate/exploration artifacts, one-root verification invocations,
  complete checked [inventory](PULSE_MIGRATION_INVENTORY.md), blocking candidate
  pilot/C CI, and independent optional latest/Rust checks. The original M1 C
  smoke covers only the value pilot. See DR-0018; stable pins remain unchanged.
- [x] **M2: Verified ingress port.** Shared Low*-independent stream model,
  stable representation bridge, and real Pulse prefix/body/FIN/ID/error behavior
  with reference/array ownership. Both implementations prove exact transitions
  and byte-copy footprints; shared validity/body-fragmentation lemmas, stable
  audit regressions and imperative Pulse tests cover closed/invalid states.
  Required candidate gate and inventory include all new proof roots. See
  DR-0019 for conditional validity and unchanged invalid-state behavior;
  actual Pulse C extraction/integration is covered by M3.
- [x] **M3: Integrated C boundary.** Real reference/array C extraction and strict
  compilation; versioned C-only ABI with reviewed, unverified marshalers. Actual
  shell receive/FIN selects Pulse in `pulse-integration-check`; 1071 differential
  comparisons, audit, callback and live loopback tests pass. Source/artifact and
  compiled-selection guards prevent stale/legacy test substitution. See
  [PULSE_C_ABI.md](PULSE_C_ABI.md) and DR-0020 for caller/trust obligations.
  Stable defaults and pins remain unchanged; this is not M4/M5 promotion.
- [/] **M4: Remaining modules.** Port multiplexer, egress/completion, worker/
  shell boundaries, parser buffer adapters, and sequential cache operations.
  Reuse pure models; explicitly port or retire unused legacy interfaces without
  silently dropping proof coverage. Review every inventory entry.

  - [x] First table slice: real Pulse lookup/allocation/close ownership proofs,
    shared permutation lemmas, imperative proof tests and standalone checked C
    extraction/tests. Stable table implementation retained. See DR-0021.
  - [x] Integrate shell table lifecycle through a reviewed C-only ABI in the
    separate table-enabled lane. Preserve embedded identity, idempotent open,
    reset/completion bookkeeping and byte storage; validate caller descriptors
    and document live/exclusive storage and serialization obligations. The new
    adapters are trusted, not a proof of raw-pointer ownership. See DR-0022.
  - [ ] Port remaining ingress wrappers, egress/completion, worker/shell/parser
    buffers and sequential cache; resolve every remaining inventory disposition.
- [ ] **M5: Stable promotion.** Pass full verification, EverParse, extraction,
  C compile/link, and all MsQuic smoke gates on a clean candidate build. Review
  contract/TCB/warning/resource changes, update stable build pins and docs
  together, and retain baseline rollback instructions.

Full concurrency, RFC completeness, and runtime-validator equivalence remain
separate gates; do not make those unimplemented guarantees a prerequisite for
preserving the existing sequential ones.

### Experimental Rust extraction (independent)

- [/] Assess the ref-based Rust path. The configured extraction pipeline still
  reports missing `Pulse.Lib.Reference.op_Bang` implementation on the evaluated
  F* `v2026.09.13`; this is not a demonstrated Pulse/C limitation.
- [x] Extract a value-state pilot and compile/run generated Rust plus an
  extern-friendly static library called from C using `make pulse-rust-smoke`.
- [x] Document experimental ABI and Rust-specific promotion gates in
  [UNVERIFIED_SHELL.md](UNVERIFIED_SHELL.md#pulserust-migration-abi) and DR-0014.
- [ ] Revisit Rust runtime support, ownership, semantic coverage, generated-code
  quality, and real integration before proposing a separate Rust promotion.
  A passing value-only smoke does not close the failed ref-based path.

### Existing parser and build work

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

  Extraction currently verifies all scaffold modules and sends the current protocol/security/transport boundary plus narrow `DNS.Worker.Minimal` shell response helpers to KaRaMeL. The clean emitted C/link surface covers the protocol/EverParse parser boundary, generated-wrapper acceptance for a covered generated-subset packet, generated-wrapper rejection for representative reference-only shapes, `DNS.ShellBoundary.dispatch_authenticated_stream_data`, `DNS.ShellBoundary.process_ready_stream_for_response` minimal 12-byte FORMERR header for an already-processing stream, `DNS.ShellBoundary.process_ready_stream_for_empty_response` header-only empty NOERROR response for an already-processing stream, `DNS.ShellBoundary.process_ready_stream_for_validated_minimal_response` generated-validator-backed selection between a question-echoing zero-answer NOERROR response and FORMERR for uncompressed question-only requests, `DNS.ShellBoundary.dispatch_stream_reset_via_scheduler` reset/drop cleanup, verified DoQ egress framing for response bytes, `DNS.ShellBoundary.*_via_scheduler` wrappers for ingress/minimal worker/send-completion events, `DNS.ShellResponseBoundary` response send handoff/completion, a fixed-capacity C shell scaffold over those generated ABIs, a MsQuic-shaped adapter smoke path that exercises validated question-echo, invalid FORMERR, busy-send rejection, mismatched-completion rejection, reset-before-response, reset-during-send, and repeated-reset cases over fake callback data, a fixed-capacity C shell event queue that stages shell-selected events while servicing derived ready responses synchronously when ingress reaches `Processing`, a dependency-free MsQuic runtime seam that copies receive bytes into shell-owned storage before queueing and translates send-completion/reset events into the queue/adapter path, a CI `make msquic-runtime-compile-smoke` gate that syntax-checks the real stream, connection, and listener callback seams against the pinned upstream `msquic.h` header installed in the stable container, fake-API connection callback behavior coverage, no-network real MsQuic API-table link/load coverage, no-network MsQuic registration/configuration/listener lifecycle coverage, loopback ephemeral listener start/stop coverage, and a live loopback stream smoke that uses test-only credentials, permits one incoming bidirectional stream, sends a valid DoQ query, and asserts that the server callback boundary copies real MsQuic receive bytes into shell-owned storage before submitting the expected generated-validator-backed DoQ response through the real MsQuic send path and validating the exact bytes received by the client. The full `DNS.Worker` authoritative parser/serializer/zone path remains verification-only until it is rewritten into an extraction-friendly representation. Broader rich-dispatcher integration, production polling/timer integration, and Phase 3/4 cache/concurrency scaffolds stay out of the linked smoke surface until they are rewritten into Low* or explicitly marked as trusted/specification-only boundaries.
- [x] Replace local mock specs with real dependencies or documented trusted interfaces:
  - [x] EverCrypt AEAD;
  - [x] EverCrypt cipher/helper interfaces;
  - [x] LowParse/Low* parser interfaces;
  - [x] Steel memory and Steel utility interfaces.
- [x] Make gateway allocation real by replacing the admitted plaintext buffer with verified Low* allocation/copying and explicit size/ownership proofs.
- [x] Maintain the RFC compliance matrix in `docs/PLAN.md` as parser, transport, EDNS0, and TLS work changes status.
- [/] Execute parser strategy decision:
  - [x] Keep the handwritten F*/Low* parser as the bootstrap/reference parser.
  - [x] Add tests against the handwritten reference parser.
  - [/] Integrate an EverParse-generated parser/serializer as the production target. Current work adds a production-target boundary candidate for the implemented header/question/RR subset, runs the shared parser fixtures through that boundary, checks in a 3D grammar seed for bounded uncompressed-QNAME question validation, a single-answer RR packet subset, a two-A-answer packet subset, A/AAAA fixed-RDLENGTH answer subsets, NS/CNAME/PTR name-RDATA answer subsets, an MX preference/exchange-name answer subset, an SOA two-name/timer answer subset, an SRV priority/weight/port/target-name answer subset, a TXT character-string answer subset, an EDNS0 OPT additional-RR subset with version-0 and bounded option header/data checks, a compressed RR owner-name subset for prior valid message-name offsets, a compressed NS/CNAME/PTR RDATA subset for prior valid message-name offsets, a compressed MX exchange-name subset for prior valid message-name offsets, a compressed SOA mname/rname subset for prior valid message-name offsets, and a compressed SRV target-name subset for prior valid message-name offsets, adds explicit `make everparse-generate` and `make everparse-verify` targets, installs EverParse/3D tooling in the pinned container, runs generated subset verification in CI, removes the local LowParse shim, verifies an adapter that imports the generated validator symbols, and gates the active Low* buffer parser through the generated C wrapper for question-only packets with bounded uncompressed QNAMEs plus one-question/one-answer packets with bounded uncompressed names, one-question/two-A-answer packets with bounded uncompressed names, one-question/one-answer packets with compressed owner names pointing to prior valid message-name offsets, raw bounded RDATA, generated A/AAAA length checks, generated uncompressed and compressed NS/CNAME/PTR name-RDATA shape checks with compressed pointers resolving to prior valid message-name offsets, generated uncompressed and compressed MX exchange-name shape checks with compressed pointers resolving to prior valid message-name offsets, generated uncompressed and compressed SOA shape checks with compressed pointers resolving to prior valid message-name offsets, generated uncompressed and compressed SRV target-name shape checks with compressed pointers resolving to prior valid message-name offsets, generated TXT shape checks, and generated EDNS0 OPT shape checks; the active production boundary now rejects packets outside the generated subset, and full packet construction for accepted packets still uses the handwritten reference parser.
  - [x] Extend the generated boundary to cover EDNS0 OPT additional records with bounded option headers/data.
  - [x] Extend the generated boundary to cover compressed RR owner-name pointers to prior valid message-name offsets.
  - [x] Extend the generated boundary to cover common compressed NS/CNAME/PTR RDATA pointers to the question name.
  - [x] Extend the generated boundary to cover compressed NS/CNAME/PTR RDATA pointers to prior valid message-name offsets.
  - [x] Extend the generated boundary to cover common compressed MX exchange-name pointers to the question name.
  - [x] Extend the generated boundary to cover compressed MX exchange-name pointers to prior valid message-name offsets.
  - [x] Extend the generated boundary to cover common compressed SOA mname/rname pointers to the question name when the other SOA name is uncompressed.
  - [x] Extend the generated boundary to cover both common compressed SOA mname/rname pointers to the question name.
  - [x] Extend the generated boundary to cover compressed SOA mname/rname pointers to prior valid message-name offsets.
  - [x] Extend the generated boundary to cover compressed SRV target-name pointers to the question name.
  - [x] Extend the generated boundary to cover compressed SRV target-name pointers to prior valid message-name offsets.
  - [x] Document the boundary/reference equivalence contract and generated-subset limits in [PARSER_EQUIVALENCE.md](PARSER_EQUIVALENCE.md).
  - [/] Replace the handwritten parser or prove runtime behavioral equivalence before Phase 1 is production-ready. Pure-model subset accept/reject lemmas and byte-exact buffer accepted-value soundness are implemented. The real generated validator and C wrapper still lack the success/failure semantic refinement needed for runtime acceptance equivalence; see [PARSER_EQUIVALENCE.md](PARSER_EQUIVALENCE.md).

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
- [/] Implement `DNS.Protocol.header_validator` and `header_reader` using EverParse. Current code has pure byte-list header/RR parsing, minimal full-packet byte serialization for uncompressed names/raw RDATA, a verified Low* buffer reader, an `EverParseBoundary` module that routes through a production-target subset boundary matching the reference parser only for generated-subset packets, a checked-in 3D grammar seed plus generator/verification targets for bounded uncompressed-QNAME question validation, a single-answer RR packet subset, a two-A-answer packet subset, A/AAAA fixed-RDLENGTH answer subsets, NS/CNAME/PTR name-RDATA answer subsets, an MX preference/exchange-name answer subset, an SOA two-name/timer answer subset, an SRV priority/weight/port/target-name answer subset, a TXT character-string answer subset, an EDNS0 OPT additional-RR subset, a compressed RR owner-name subset for prior valid message-name offsets, a compressed NS/CNAME/PTR RDATA subset for prior valid message-name offsets, a compressed MX exchange-name subset for prior valid message-name offsets, a compressed SOA mname/rname subset for prior valid message-name offsets, and a compressed SRV target-name subset for prior valid message-name offsets, containerized EverParse/3D tooling, CI generation of the subset artifact, no local LowParse shim, an EverParse-verified adapter that imports the generated validator symbols, and an active Low* buffer gate through the generated C wrapper for question-only packets with bounded uncompressed QNAMEs plus one-question/one-answer packets with bounded uncompressed names or compressed owner names pointing to prior valid message-name offsets, one-question/two-A-answer packets with bounded uncompressed names, raw bounded RDATA, generated A/AAAA length checks, generated uncompressed and compressed NS/CNAME/PTR name-RDATA shape checks with compressed pointers resolving to prior valid message-name offsets, generated uncompressed and compressed MX exchange-name shape checks with compressed pointers resolving to prior valid message-name offsets, generated uncompressed and compressed SOA shape checks with compressed pointers resolving to prior valid message-name offsets, generated uncompressed and compressed SRV target-name shape checks with compressed pointers resolving to prior valid message-name offsets, generated TXT shape checks, and generated EDNS0 OPT version/option-shape checks; packets outside the generated subset are rejected by the active production boundary, and full packet construction for accepted packets still uses the handwritten reference parser.
- [/] Implement recursive `parse_qname` with fuel-based termination for name compression. Current code parses uncompressed question names, enforces the 255-byte DNS name length budget, accepts RR owner-name, NS/CNAME/PTR RDATA-name, MX exchange-name, SOA mname/rname, and SRV target-name compression pointers to prior message offsets, and rejects self-loop, forward, out-of-range, and question-name compression pointers.
- [/] Implement full `DNS_Packet` parser (Header + Question + RR sections). Current `DNS.Protocol.Parser` parses header, question, and RR sections from byte lists; RR parsing preserves bounded RDATA bytes, maps unknown types to `UNKNOWN`, validates A/AAAA RDATA lengths, validates NS/CNAME/PTR/MX/SOA/TXT/SRV RDATA shapes, accepts compressed RR owner names, NS/CNAME/PTR RDATA names, MX exchange names, SOA mname/rname names, and SRV target names pointing to prior names, and accepts structurally valid EDNS0 OPT pseudo-RRs/options in the additional section, but broader type-specific RDATA validation is not implemented yet.
- [/] **Validation:** Prove parser is "parser-rejecting" for malformed inputs. Current name/header/question/buffer proofs are admitted-free, and tests cover RR truncation, A/AAAA RDATA length rejection, name-bearing, MX, SOA, TXT, SRV, and generated EDNS0 OPT rejection cases, malformed OPT rejection, malformed EDNS option rejection, valid compressed RR owner names, valid compressed CNAME RDATA names including generated prior-offset coverage, valid compressed MX exchange names including generated prior-offset coverage, valid compressed SOA mname/rname names including generated prior-offset coverage, valid compressed SRV target names including generated prior-offset coverage, and malformed RR owner/RDATA-name compression pointers; broader type-specific RR parser obligations remain incomplete.

## Phase 2: DoQ Transport Layer (QUIC + TLS 1.3)
*Goal: Verified DoQ stream handling above a maintained unverified QUIC/TLS shell stack.*

- [x] Define `crypto_context` for session state.
- [/] Delegate TLS 1.3 handshake and authentication policy to the MsQuic shell stack. Current `DNS.Security.Handshake` defines the state type and transitions, but `verify_client_hello` still delegates success/failure to the trusted `EverCrypt.Cipher.validate_client_hello` bootstrap adapter until the shell boundary bypasses it.
- [/] Replace `DNS.Security.Gateway` authenticated decryption with authenticated stream-byte ingress from the MsQuic shell stack. Current decrypt delegates success/failure to the trusted `EverCrypt.AEAD.decrypt_authenticated` bootstrap adapter, and the gateway copies the bounded ciphertext range into a concrete Low* plaintext workspace before parsing it instead of admitting allocation; `DNS.QUIC.MsQuicIngress.handle_authenticated_stream_fragment` is now the preferred verified ingress boundary for authenticated MsQuic stream bytes.
- [/] Implement `DNS.QUIC.StreamMapping` state machine. Bounded Low* reads and copies handle split length prefixes and body fragments. Exact completion enters `AwaitingFin`; explicit peer FIN with a zero message ID permits `Processing`. Short lengths, premature FIN, and excess bytes (including later fragments) fail. State transitions have semantic contracts and a body-count fragmentation lemma; whole-trace byte accumulation, callback refinement, and global resource proofs remain incomplete.
- [/] Implement Stream ID Multiplexer under serialized access. `find_stream` specifies matching IDs; allocation refuses duplicates and preserves other active contexts under disjointness preconditions. Close swaps removed/last pointers, retaining distinct active and available slots. A full connection invariant spanning IDs, message buffers, initialization, and wrappers remains open; this is not a concurrent ownership proof.
- [/] Implement EDNS0 (OPT) handling and padding policy. Padding length helpers and basic option serialization exist, and structural OPT parsing accepts version 0 with bounded options. Automatic response-policy integration and traffic-analysis protection are not established.
- [/] **Validation:** Prove the verified core only processes authenticated stream bytes. Current code models the boundary through a trusted AEAD adapter result; the accepted architecture moves authenticity to the MsQuic shell stack, `DNS.QUIC.MsQuicIngress` defines the explicit shell/core ingress contract, and the C shell now has a MsQuic-shaped adapter scaffold over fake callback data that routes ready streams through the generated-validator-backed response selector. The stable container also links/runs no-network MsQuic API-table, registration/configuration/listener lifecycle, loopback listener-start, and live loopback stream smokes against the pinned shared library, syntax-checks listener new-connection, connection peer-stream, and stream callback seams against the pinned upstream header, and runs fake-API behavior coverage for connection and peer-stream callback dispatch. Remaining work is to wire production socket polling, timers, event-loop behavior to that contract and bypass the legacy decrypt/client-hello adapters.

## Phase 3: Verified Core Logic & Backend
*Goal: Functional correctness of lookup and response generation.*

- [x] Define `rcode` sum types and `dns_result` core type.
- [/] Implement Verified Static Zone File parser (Master File format). Current code parses one bootstrap binary zone-entry shape with origin QNAME, TTL, CLASS, TYPE, RDLENGTH, and exact RDATA bytes; validates A/AAAA RDLENGTH; and rejects truncated, trailing, and invalid A/AAAA entries. Full master-file text parsing and multi-entry iteration are incomplete.
- [/] Implement In-Memory Radix Tree for authoritative lookups. Exact lookup, literal `*` wildcard fallback, and a pure authoritative request adapter are implemented over the in-memory tree; tree construction/loading is not implemented.
- [/] Implement CNAME chasing logic with hop-count limits. Current code inspects CNAME records, decodes uncompressed target names from RDATA, follows targets with the existing hop bound through the authoritative request adapter, returns `ServFail` on malformed CNAME targets or hop exhaustion, and returns `NXDomain` when a followed target is absent; broader CNAME/RRset semantics remain incomplete.
- [/] Implement Recursive Resolver logic with Bailiwick validation. Current `validate_answer` rejects records whose owner name is not under the authority zone using a verified DNS-name suffix check; broader recursive answer validation remains incomplete.
- [/] Implement Verified Cache with absolute TTL enforcement. TTL validity, saturated expiry calculation, and conservative first-slot lookup/insertion are present; full bounded scanning, eviction, and replacement policy are incomplete.
- [/] **Validation:** Prove that response generation never leaks cross-thread memory. A pure authoritative response adapter now maps parsed requests through lookup/CNAME resolution into response packets, the response packet builder echoes request questions, maps success records to the answer section, maps error results to empty-answer responses with the selected RCODE, and the worker `Processing` branch parses completed stream buffers, builds response bytes, copies them into a caller-provided Low* response buffer with an explicit capacity check, and prepares a MsQuic send descriptor for that buffer. `DNS.QUIC.MsQuicSendCompletion.complete_response_send` models close cleanup after the shell completes or drops the send, and the C adapter tracks one in-flight send buffer until matching completion. Broader cross-thread buffer lifetime and aliasing proofs are not present.

## Phase 4: Secure Concurrency & I/O Integration
*Goal: Thread-safe execution using Pulse, separately from the sequential migration.*

- [/] Implement `DNS.Cache.Sharded` using real Pulse invariants for thread-safe access. Current code still uses the unit-valued Steel compatibility permission and routes sequential get/add through the first shard. The migration first preserves those sequential contracts; real shard selection, synchronization, and concurrent ownership proofs remain separate work.
- [/] Implement the Worker Thread harness (`worker_loop`). Current harness uses verified stream lookup, reads a matching active stream context, parses completed `Processing` stream buffers into response bytes, copies the serialized response into a caller-provided Low* response buffer, wraps response bytes in a DoQ length-prefixed stream buffer, prepares a MsQuic send descriptor without admits, exposes a verified send-completion/drop cleanup boundary that closes the stream, routes shell-selected events through `DNS.ShellScheduler.dispatch_shell_event`, exposes generated C ingress and minimal worker FORMERR/header-only empty NOERROR/generated-validator-backed question-echo response ABIs through `DNS.ShellBoundary`, exposes C-shaped scheduler helper wrappers for ingress/minimal worker/send-completion events, exposes `DNS.ShellBoundary.dispatch_stream_reset_via_scheduler` for reset/drop cleanup without an in-flight send, exposes `DNS.ShellResponseBoundary` C symbols for response send handoff/completion and DoQ egress framing, has a fixed-capacity C shell scaffold that owns connection/stream buffers and calls those generated ABIs, has a MsQuic-shaped C adapter scaffold whose fake callback smoke coverage uses the generated-validator-backed question-echo/FORMERR selector, single-send in-flight tracking, and reset/drop cleanup, has a fixed-capacity C shell event queue with smoke coverage for FIFO order, overflow rejection, synchronous ready-response service after completed ingress, send-completion cleanup, and reset cleanup, has a real-MsQuic stream callback seam that copies `QUIC_STREAM_EVENT` receive bytes into shell-owned storage before queueing and maps send-completion/reset shapes into the queue/adapter path, has a real-MsQuic connection callback seam that accepts listener `NEW_CONNECTION` events, sets connection configuration, reads peer-started stream IDs, maps them into fixed shell-owned stream slots, installs the stream callback, and closes the MsQuic stream handle when stream shutdown completes, syntax-checks those seams against pinned upstream `msquic.h` in CI, and covers listener new-connection, peer-stream mapping, stream callback installation, shutdown cleanup, and rejected-stream closure with a fake MsQuic API-table behavior smoke, has a no-network smoke binary that opens and closes the pinned MsQuic shared library API table, has a no-network lifecycle smoke that opens/closes MsQuic registration, configuration, and listener handles, has a listener-start smoke that binds a loopback ephemeral UDP listener, and has a live loopback stream smoke that sends a valid DoQ query from a real client stream into the server receive callback boundary and validates the exact DoQ response bytes received by the client after real `StreamSend` submission and completion. The C-linked shell bundle uses `DNS.Worker.Minimal` for the current narrow response paths, while the full parser/serializer/zone-backed `DNS.Worker` remains verification-only. Real polling, production worker response extraction, rich-dispatcher C ABI coverage, and C/MsQuic scheduler integration remain incomplete.
- [/] Integrate with the documented [Unverified Shell](UNVERIFIED_SHELL.md) for UDP/QUIC socket I/O. Current work adds `shell/ism_shell.c` as a fixed-capacity shell-owned buffer and stream-context scaffold over the generated ingress/egress/reset ABIs, `shell/msquic_adapter.c` as a MsQuic-shaped callback adapter that prepares DoQ length-prefixed validated-minimal response bytes and handles reset/drop cleanup, `shell/ism_event_queue.c` as a fixed-capacity local event queue, `shell/msquic_runtime.c` as a real-MsQuic callback receive-copy/send-completion/reset seam, `shell/msquic_connection_runtime.c` as a real-MsQuic listener/connection/peer-stream callback attachment seam checked against pinned upstream `msquic.h` and covered by a fake-API behavior smoke, a no-network real-library link/load smoke, a no-network lifecycle smoke that opens/closes registration, configuration, and listener handles, a listener-start smoke that binds loopback UDP on an ephemeral local port, and a live loopback stream smoke that uses test-only credentials to exercise real MsQuic receive and send callbacks, validate exact response bytes at the client, and observe send completion. It still does not wire production polling, timers, production allocation, or multi-send buffer ownership.
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

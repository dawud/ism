# Threat model and trusted-boundary inventory

This is a prototype with conditional component proofs. It does not establish end-to-end DNS correctness, race freedom, cryptographic security, constant-time behavior, or deployment safety.

## Current protections and limits

| Threat | Implemented protection | Limit |
| --- | --- | --- |
| Malformed wire input | Bounds-checked Low* access, bounded names, structural parsing, generated subset validators, contextual compression checks | Supported grammar only; not all DNS/RDATA semantics |
| Stream confusion | Active/available slot swap, allocation preservation contract, zero-ID check, exact length plus FIN before processing | Requires disjoint caller-owned storage and serialized calls |
| Cache poisoning | Case-insensitive label-suffix check at insertion, record-shape check | Not complete recursive response validation, DNSSEC, ranking, or referral policy |
| Expired cache answers | Lookup rejects expiry and decreases returned TTL | First-slot cache only; trusted monotonic time; no negative cache |
| Transport tampering / spoofing | MsQuic and configured TLS provider | Entire authentication/crypto/transport boundary is trusted here |
| Resource exhaustion | Local buffer capacities, parser fuel, CNAME hop limit | No global CPU/memory/connection/concurrent resource theorem |
| Timing / traffic analysis | No established protection | No constant-time cache, jitter, bucketization, or automatic padding policy |
| Repudiation / quantum attacks | No established protection | No verified logging, hybrid KEM, ML-DSA, or PQC workspace invariant |

## Trusted-boundary inventory

Keep this inventory current when assumptions, mocks, interfaces, or adapters change. No new admissions or cryptographic/concurrency axioms are introduced by the proof-audit remediation.

| Boundary | What is trusted or incomplete | Required closure |
| --- | --- | --- |
| F*, Pulse, Z3, libraries, extraction, C compiler/runtime | Proof checking, Pulse elaboration/library contracts, and Low*/KaRaMeL translations; generated C is not independently verified. Warning-15 GC/list extraction debt remains. CompCert is not in the build. | Audit/pin dependencies, reduce extraction debt, retain extraction and C gates |
| Local `spec/*.fsti` | Abstract declarations are trusted contracts even without `admit`. Real imported Low* contracts do establish sequential bounds/liveness, but do not strengthen weaker local interfaces automatically. | Review each interface against linked implementation |
| `EverCrypt.AEAD.fsti` | Legacy `decrypt_authenticated` result is abstract; authenticity/plaintext semantics are not proved. Gateway copying ciphertext after this result is not a cryptographic implementation. | Keep legacy path outside runtime; retire or replace with real contracts |
| `EverCrypt.Cipher.fsti` | Legacy ClientHello validation is abstract, not a TLS/authentication proof. `EverCrypt.Helpers` and `Spec.Agile.Cipher` are import shims. | Runtime uses MsQuic; retire unused shims |
| MsQuic / TLS / OS / hardware | Authentication, certificate policy, encryption, address validation, flow control, socket I/O, timers, ordering, and machine behavior | Audit configuration and integration; no local crypto theorem |
| Unit authentication/borrow tokens | `msquic_authenticated` and `msquic_stream_borrow` are `unit`, not unforgeable authentication or ownership capabilities | Caller must establish the documented preconditions |
| EverParse C wrapper and adapter | Generated grammar verifies separately. Runtime wrapper booleans have no success/failure semantic refinement in the local interface. The pure `EverParseGenerated` module is handwritten, not the generated implementation. | Relate generated success/failure to the byte-level model; runtime completeness/equivalence remains open |
| General buffer parser | Accepted values equal the pure parse of a byte-exact input snapshot, independently of the wrapper's boolean semantics; rejection may depend on that wrapper | No RFC completeness claim; see [parser contract](PARSER_EQUIVALENCE.md) |
| Compression model | Structural name-offset scanner excludes non-name fields; chains decrease and names are bounded. Standalone generated validators do not establish contextual target provenance. | Extend supported contexts and prove grammar-wide scanner/parser correspondence |
| Serializer / raw RDATA | Successful packet serialization round-trips through the reference parser. Embedded compressed RDATA is rejected rather than relocated; opaque types only receive structural checks. | Typed semantic RDATA and completeness on a declared full domain |
| Steel compatibility / cache shards | `vprop = unit`, `shard_permission = ()`; no locks, concurrent permissions, or race-freedom theorem; first shard/slot only | Exclusive serialized access is mandatory; real concurrent invariants are a separate gate |
| Stream table | Close proves slot permutation/distinctness preservation; allocation requires separated contexts and preserves other active slots. Raw C initialization must satisfy these assumptions. | Full reusable connection invariant including IDs, message buffers, and all wrappers remains a promotion gate |
| C shell / queue / callbacks | All buffers, aliases, lifetimes, truthful FIN/completion/reset notifications, stream IDs, and exclusive access are trusted. FIN is propagated; callback error handling and storage are tested, not formally verified. Single tracked send slot requires explicit ready-stream scheduling. | Audit/fuzz trace ordering, failure paths, scheduler and multi-send ownership |
| Minimal linked responder | Zero-ID uncompressed question-only response selector; echoes question in zero-answer NOERROR or emits FORMERR. Not an authoritative or recursive server. | Connect and verify production worker, zone/cache policy and response semantics |
| Full worker / authoritative logic | Test-zone default, partial CNAME/wildcard/RRset logic; worker loop discards send descriptor; not linked production processing | Semantic zone model, full response synthesis, extraction/link integration |
| Binary zone parser | One binary entry, not an RFC text master-file loader | Multi-entry loading, full supported RDATA validation, semantic tree construction |
| Recursive cache / bailiwick | First-slot semantic lookup/insertion contracts; TTL aging and saturated expiry; caller supplies trusted time and authority zone. Suffix validation alone is insufficient against poisoning. | Referral/ranking/query/type/class/DNSSEC policy, eviction and negative caching |
| Pulse stream candidate | Shared pure model and real reference/array implementation prove transitions, exact copies and ownership preservation under separate caller-owned storage. M3 extracts the real port to C and selects it in the explicit mixed integration lane. Validity is conditional, not sanitization of every typed state. No new admissions or ownership axioms. | Remaining imperative ports and promotion are M4/M5; local separation proofs do not prove runtime synchronization |
| Pulse C marshalers (M3) | `shell/pulse_stream_adapter.c` and `migration/c/ism_pulse_stream.c` are new unverified C adapters. Explicit conversions, range/alias checks, fixed layouts, artifact hashes and differential tests supplement review, not a proof that raw pointers establish Pulse resources. True liveness/capacity, disjoint context/message/input and exclusive access remain caller obligations. Runtime copies receive data into owned ingress storage before synchronous dispatch. | Retain the [ABI/ownership contract](PULSE_C_ABI.md), review callers and both conversions; no forged-pointer safety or end-to-end C ownership theorem. Stable default is unchanged |
| Migration Pulse/C and Rust pilots | Original pilots still checked independently of real stream C extraction and integration. Separate optional Rust extern wrapper remains unverified. | Keep pilot evidence distinct from real stream proof/integration evidence; Rust gates remain separate |
| Build reproducibility | Stable pins unchanged. Candidate F*/Pulse/KaRaMeL/solver bundle has a checked archive digest and tool identities; compiler/OS provenance recorded. Base image, system/opam packages and remaining transitive inputs are not fully locked. | Do not claim a fully reproducible supply chain |

## Operational assumptions

All calls touching a shared connection, stream table, cache, event queue, or send slot must be exclusive and serialized, including MsQuic callbacks for different streams. Current callback tests do not establish production synchronization. The shell must hold send storage unchanged until matching completion and must never recycle live contexts. Zero-ID, premature-FIN, or extra-byte failures must close the owning DoQ connection; malformed supported DNS requests may instead receive FORMERR.

Transport address validation and amplification policy belong to MsQuic/configuration, not a local proof. Parser termination and finite buffers do not prevent aggregate denial of service. Test loopback credentials and authentication bypasses must not be deployed.

The TCB includes specifications, proof tools/libraries, generated-wrapper interfaces, extraction, runtime/compiler, C adapters/scheduler, MsQuic/TLS/configuration, OS and hardware. The unresolved items above are not removed by a passing `make verify`.

# Architecture and verification scope

ISM is a DNS-over-QUIC prototype with verified F*/Low* components, not an end-to-end verified DNS server. Verification establishes the contracts actually written, under caller preconditions and the trusted interfaces in [THREAT_MODEL.md](THREAT_MODEL.md).

## Current linked path

```text
MsQuic (trusted TLS/QUIC)
  -> C receive-copy and serialized event dispatch
  -> Low* DoQ length/body accumulation, then FIN
  -> minimal zero-ID request validation + generated question validator
  -> question-echo / zero-answer NOERROR, or FORMERR
  -> Low* two-byte response framing
  -> C single-send ownership -> MsQuic -> completion cleanup
```

Protocol errors (short framing, premature FIN, excess bytes, nonzero DNS ID) are distinct from malformed DNS questions. The connection runtime closes the owning connection on fatal DoQ errors. The minimal responder does not perform authoritative lookup or recursive resolution.

## Reference/model path

The general parser reads the actual buffer bytes, applies a generated subset gate, and constructs a packet with the handwritten pure parser. Its postcondition proves accepted-value soundness relative to that parser. It does not prove acceptance equivalence with the external C validator; see [PARSER_EQUIVALENCE.md](PARSER_EQUIVALENCE.md).

Compressed targets must be earlier structural name-suffix offsets collected from question names, RR owners, or supported name-bearing RDATA. Targets in headers, label payloads, and opaque RDATA are not valid name offsets. Pointer targets decrease along a chain. This is a deliberately restricted compression model, not complete DNS grammar coverage.

Names remain in wire order and preserve spelling. A distinct traversal-key conversion reverses them for the TLD-first radix tree. ASCII case-folded comparison is shared by tree, cache, and bailiwick logic.

The authoritative tree, binary single-entry zone loader, first-slot cache, and full worker are verification/model components outside the linked minimal responder. CNAME chasing is fuel-bounded but does not implement complete CNAME/RRset synthesis; wildcard lookup is not full RFC 4592 closest-encloser semantics. Cache insertion applies a suffix-based bailiwick check, not complete referral, ranking, or DNSSEC policy.

The general serializer rejects inconsistent lengths and unsupported embedded-name encodings. A successful full-packet serialization is checked against the pure parser and guarantees an exact parse-back. This costs an additional parse; it is not a completeness theorem or a production performance claim.

## Ownership and concurrency

Low* proves sequential buffer-access bounds, liveness, disjointness obligations, and specified mutation/semantic results. Stream close swaps active and available slots; allocation initializes the next available slot and preserves other active contexts under explicit ownership preconditions.

The local Steel adapter defines `vprop = unit`. It supplies no exclusive capability, lock, race-freedom proof, or concurrent resource invariant. Callers must serialize access to each connection, stream table, cache, queue, and shared send buffer. The C scaffold is not a production multi-threaded scheduler.

TLS authenticity, certificates, transport flow control, and cryptography are delegated to MsQuic and its TLS provider. Logging, constant-time cache access, jitter, automatic padding policy, PQC, global CPU/memory budgets, and CompCert integration are not implemented/proved mitigations here.

## Remaining promotion gates

Real concurrent ownership, full DNS semantics, external-validator semantic equivalence, and production extraction/integration are separate gates. Passing verification, extraction, fixtures, or loopback tests alone does not close them. See [TODO.md](TODO.md) and [UNVERIFIED_SHELL.md](UNVERIFIED_SHELL.md).

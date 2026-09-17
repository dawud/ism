# Proof-audit remediation

Plan: September 11 audit of `bf584e2` (original report supplied at
`/tmp/ism-proof-audit.1D4RE3/REPORT.md`). This document records implementation
scope and evidence; it does not declare every recommended proof complete.

| Finding | Implemented action | Remaining assurance gate |
| --- | --- | --- |
| Stream close/reallocation | Swap removed/last slots, retain available partition, refuse duplicate F* allocation; strengthen find/allocate/close contracts and C regressions | Reusable whole-connection invariant spanning all IDs, message buffers and wrappers; verified C initialization |
| Name order | Wire-order names, explicit distinct traversal-key conversion, corrected normal and CNAME fixtures | General semantic zone mapping, zone-loader/tree correspondence, full CNAME/RRset synthesis |
| Compression provenance | Structural name-field offsets, decreasing targets; generated pointer fields reject header offsets; header/label/opaque-data regressions | Grammar-wide scanner/parser correspondence and complete supported-context specification |
| Runtime parser relationship | Byte-exact read contract; buffer-parser accepted-value soundness independent of external boolean semantics | Real generated-wrapper success/failure equivalence and completeness; no replacement axiom added |
| Concurrency | Mandatory exclusive serialized access documented; false Steel/race-freedom claims removed | Real concurrent invariants or verified scheduler; unit permissions remain explicit trusted debt |
| DoQ lifecycle | Awaiting-FIN state, zero ID, short/excess-body rejection, FIN propagation/deduplication, owning-connection protocol-error shutdown | Full byte-trace refinement and callback/scheduler proof; currently body-count fragmentation theorem plus exhaustive split regressions |
| Name comparison | Shared ASCII case folding; reflexive/symmetric/transitive name-equality lemmas; cache/tree/bailiwick use it | Full case-preserving response-synthesis semantics |
| Serializer | Consistent RDLENGTH, supported RDATA-shape checks, reject compressed RDATA relocation, checked successful packet round-trip contract | Typed RDATA and completeness; opaque types retain only structural validation; checked construction adds a parse |
| Security claims | README, architecture, parser contract, threat model and roadmap distinguish proofs, tests, trust and plans | Logging, timing mitigation, automatic padding policy, PQC and global resource proofs are not implemented |
| Worker/cache/toolchain scope | First-slot cache has semantic lookup/insertion contracts, aged TTL and guarded bailiwick insertion; KaRaMeL pinned; minimal worker scope explicit | Full recursive validation/cache/production worker extraction, scheduling, multi-send ownership and locked supply chain |

An additional regression discovered during remediation corrected the minimal
error responder's wire RCODE from NXDOMAIN (3) to FORMERR (1), matching its API
and documentation. The byte-level FORMERR result is now in its postcondition.
The linked C smoke recipes now stop on compiler failure instead of potentially
executing a stale binary. Named checks identify which linked regression failed.

## Regression and verification gates

- `make verify` includes `DNS.ProofAudit.Tests.fst`: corrected audit
  counterexamples, pointer provenance, wire-order lookup, case comparison,
  invalid serialization, TTL aging and DoQ state transitions.
- `make c-link-smoke` includes `link_proof_audit_smoke.c`: every two-fragment
  split of valid/overlong queries, all premature-FIN truncations, small lengths,
  zero/nonzero IDs, active/available pointer preservation, and the generated
  header-pointer rejection.
- Existing shell/adapter/queue/runtime fixtures now deliver explicit FIN,
  use zero DoQ IDs and normal wire-order names.
- The fake real-MsQuic API test checks owning-connection DOQ_PROTOCOL_ERROR for
  early FIN, nonzero ID and both coalesced/split excess bytes.
- Required release evidence: `make verify`, `make everparse-verify`,
  `make extract`, `make c-compile-smoke`, `make c-link-smoke`,
  `make msquic-runtime-compile-smoke`, `make msquic-runtime-connection-smoke`
  and `make msquic-runtime-stream-smoke`.

## Verified results (2026-09-17)

The remediation checkout passed the following gates in
`localhost/verified-dns-server:latest`:

- `make verify`: all verification conditions discharged, including
  `DNS.Protocol.Parser.Tests`, `DNS.Worker`, and `DNS.ProofAudit.Tests`.
- `make everparse-verify`: regenerated grammar, implementation, interface, and
  adapter verification passed.
- `make extract`: C/H artifacts regenerated successfully.
- `make c-compile-smoke` and `make c-link-smoke`: passed, including the new
  audit regressions.
- `make msquic-runtime-compile-smoke` and
  `make msquic-runtime-connection-smoke`: passed, including protocol-error
  shutdown tests against the fake API.
- `make msquic-runtime-link-smoke`, `make msquic-runtime-lifecycle-smoke`,
  `make msquic-runtime-listener-smoke`, and
  `make msquic-runtime-stream-smoke`: passed, including the live loopback
  query/response exchange.

Reproduction (the prerequisites run verification, generation, and extraction):

```bash
podman run --rm --userns=keep-id \
  -v /home/david/Code/git/localhost/ism:/workspace:z \
  localhost/verified-dns-server:latest bash -lc \
  'make c-compile-smoke c-link-smoke msquic-runtime-compile-smoke msquic-runtime-connection-smoke msquic-runtime-link-smoke msquic-runtime-lifecycle-smoke msquic-runtime-listener-smoke msquic-runtime-stream-smoke'
```

After hardening the recipes, the three linked gates were rebuilt and rerun
against those same fresh extracted artifacts with `make -o extract`. A negative
control, `make -o extract CC=false c-link-smoke`, failed as expected despite an
existing passing binary. `git diff --check` passed. A source scan found no
explicit project `admit`, `assume`, `magic`, or `--lax` additions.

The tested image reports F* `2026.03.24` and KaRaMeL commit
`11bb8e1ac2f720fb7144b9b768c7251526caa149`, matching the new stable pin. The
Containerfile itself was not rebuilt during this run. Existing ignored-binder,
upstream-library, deprecated extraction-option, KaRaMeL warning-15 GC/list, and
`KRML_CHECK_SIZE` redefinition warnings remain; this is not a warning-free or
fully reproducible production build.

These results close the implemented repair/regression gates, not the remaining
assurance gates in the table. In particular, no runtime-validator completeness,
whole-runtime trace, general zone semantics, or concurrency theorem is claimed.

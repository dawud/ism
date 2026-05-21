# Parser Equivalence Contract

This document records the current relationship between the handwritten DNS
parser and the EverParse-generated production-target boundary.

## Current Boundary

The active parser boundary is `EverParseGeneratedSubset` in
`DNS.Protocol.Parser.EverParseBoundary`. The boundary routes packet construction
through `parse_dns_packet_bytes_generated`, and the repository keeps the
reference parser result as the semantic contract:

- `parse_dns_packet_bytes_at_boundary input == parse_dns_packet_bytes input`
- reference acceptance implies boundary acceptance;
- reference rejection implies boundary rejection.

Those obligations are named in:

- `lemma_boundary_matches_reference`
- `lemma_boundary_matches_reference_on_generated_subset`
- `lemma_boundary_accepts_reference_result`
- `lemma_boundary_rejects_reference_rejection`

The shared fixture tests also assert boundary/reference equality across the
implemented valid and malformed packet examples.

## Generated Subset

The generated validator gate currently covers:

- question-only packets with bounded uncompressed QNAMEs;
- one-question/one-answer packets with bounded uncompressed question and owner
  names;
- raw bounded RDATA;
- generated A/AAAA fixed-RDLENGTH checks;
- generated NS/CNAME/PTR name-RDATA shape checks for uncompressed names;
- generated NS/CNAME/PTR compressed name-RDATA checks for pointer offsets that
  resolve to prior valid message names;
- generated MX exchange-name shape checks for uncompressed names;
- generated MX compressed exchange-name checks for pointer offsets that resolve
  to prior valid message names;
- generated SOA mname/rname/timer shape checks for uncompressed names;
- generated SOA compressed mname/rname checks for pointer offsets that resolve
  to prior valid message names when the other SOA name is uncompressed;
- generated SOA both-compressed mname/rname checks for pointer offsets that
  resolve to prior valid message names;
- generated SRV target-name shape checks for uncompressed names;
- generated SRV compressed target-name checks for pointer offsets that resolve
  to prior valid message names;
- generated TXT character-string shape checks;
- generated RR owner-name compression checks for pointer offsets that resolve
  to prior valid message names;
- generated EDNS0 OPT additional-RR checks for root-owner/version-0 shape and
  structurally bounded option headers/data.

The generated-subset predicate is:

- `everparse_boundary_generated_subset_applicable`

Examples outside that generated validator subset may still be accepted by the
active boundary when the reference parser accepts them. These cases remain part
of the handwritten reference-parser construction path until the generated
grammar grows equivalent coverage.

## Production Gap

Phase 1 is not production-complete until one of these is true:

- the EverParse-generated grammar constructs full packets for every accepted
  production DNS packet shape, including compression and broader RR coverage; or
- the repository carries a proof-backed coexistence decision that keeps the
  handwritten parser as a verified reference construction layer behind a
  generated validator gate.

Until then, the handwritten parser remains the bootstrap/reference parser, and
EverParse is the production-target validator subset.

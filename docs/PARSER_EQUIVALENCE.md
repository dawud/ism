# Parser Equivalence Contract

This document records the current relationship between the handwritten DNS
parser and the EverParse-generated production-target boundary.

## Current Boundary

There are two different boundaries. The list-valued functions and lemmas below
model the subset policy in pure F*. Despite its historical name,
`DNS.Protocol.Parser.EverParseGenerated` is handwritten and calls the reference
parsing routines; it is not the generated `DNSProtocol.fst` implementation.
Their equivalence lemmas do not prove anything about the external C wrapper's
return value.

The executable Low* `parse_dns_packet_buffer` has a different, explicit
contract. `read_buffer_range` equals `sequence_bytes (as_seq h0 buffer) pos len`.
If the buffer parser returns `Some packet`, the reference parser on that exact
snapshot returns `Some packet`, and a generated-subset classifier applies.
The buffer is not modified. This accepted-value soundness holds even if the
external validator returns an arbitrary boolean; an always-false wrapper can
still reject every input. Acceptance completeness and success/failure
equivalence for the generated validator remain unproved.

The active parser boundary is `EverParseGeneratedSubset` in
`DNS.Protocol.Parser.EverParseBoundary`. The boundary uses the generated-subset
classifier as the production acceptance gate. Packets inside the generated
subset are constructed through `parse_dns_packet_bytes_generated`, which still
uses the handwritten parser as the semantic construction layer. Packets outside
the generated subset are rejected by the production boundary even if the
handwritten reference parser can parse them.

The pure list-model boundary contract is:

- for generated-subset packets,
  `parse_dns_packet_bytes_at_boundary input == parse_dns_packet_bytes input`;
- for packets outside the generated subset,
  `parse_dns_packet_bytes_at_boundary input == None`;
- reference rejection still implies boundary rejection.

Those obligations are named in:

- `lemma_boundary_matches_reference_on_generated_subset`
- `lemma_boundary_rejects_outside_generated_subset`
- `lemma_generated_subset_accepts_reference_result`
- `lemma_generated_subset_rejects_reference_rejection`
- `lemma_boundary_accepts_reference_result`
- `lemma_boundary_rejects_reference_rejection`

The generated-subset accept/reject lemmas make the pure coexistence policy explicit.
They do not connect the separately generated validator's semantics to that policy.
The shared fixture tests
also assert boundary/reference equality across the implemented valid and
malformed packet examples.

## Generated Subset

The generated validator gate is classified by `classify_generated_subset`.
Contextual pointer provenance is checked by the F* structural name-offset pass,
not by a standalone generated validator. Generated pointer-field checks reject
header offsets, but do not by themselves establish prior-name membership.
The current cases are:

- `GeneratedQuestionOnly`: question-only packets with bounded uncompressed
  QNAMEs;
- `GeneratedUncompressedAnswer`: one-question/one-answer packets with bounded
  uncompressed question and owner names;
- raw bounded RDATA;
- generated A/AAAA fixed-RDLENGTH checks;
- `GeneratedUncompressedTwoAAnswers`: one-question/two-answer packets where
  both answers have bounded uncompressed owner names and A RDATA;
- generated NS/CNAME/PTR name-RDATA shape checks for uncompressed names;
- `GeneratedCompressedOwner`: RR owner-name compression checks for pointer
  offsets that resolve to prior valid message names;
- `GeneratedCompressedNameRdata`: NS/CNAME/PTR compressed name-RDATA checks
  for pointer offsets that resolve to prior valid message names;
- generated MX exchange-name shape checks for uncompressed names;
- `GeneratedCompressedMx`: MX compressed exchange-name checks for pointer
  offsets that resolve to prior valid message names;
- generated SOA mname/rname/timer shape checks for uncompressed names;
- `GeneratedCompressedSoaOneName`: SOA compressed mname/rname checks for
  pointer offsets that resolve to prior valid message names when the other SOA
  name is uncompressed;
- `GeneratedCompressedSoaBothNames`: SOA both-compressed mname/rname checks for
  pointer offsets that resolve to prior valid message names;
- generated SRV target-name shape checks for uncompressed names;
- `GeneratedCompressedSrv`: SRV compressed target-name checks for pointer
  offsets that resolve to prior valid message names;
- generated TXT character-string shape checks;
- `GeneratedEdns0Opt`: EDNS0 OPT additional-RR checks for root-owner/version-0
  shape and structurally bounded option headers/data.

The generated-subset predicate is derived from the classifier:

- `everparse_boundary_generated_subset_applicable`

Examples outside that generated validator subset may still be accepted by the
handwritten reference parser, but they are rejected by the production boundary
until the generated grammar grows equivalent coverage.

## Reference-Only Accepted Shapes

The reference-only acceptance surface is classified by
`classify_reference_only_acceptance`. These are packets accepted by the
handwritten reference parser, but rejected by the active production boundary
because they are not covered by the current generated validator subset:

- `ReferenceOnlyAnswerWithoutQuestion`: response packets with answer records
  and no question section;
- `ReferenceOnlyMultipleQuestions`: packets with more than one question;
- `ReferenceOnlyMultipleAnswers`: packets with more than one answer record
  outside the generated two-A-answer subset;
- `ReferenceOnlyAuthorityRecords`: packets with non-empty authority sections;
- `ReferenceOnlyAdditionalRecords`: packets with additional records outside the
  current generated EDNS0 OPT-only additional subset;
- `ReferenceOnlyOtherAcceptedShape`: a catch-all for accepted reference-parser
  shapes not otherwise classified.

The parser tests include representative accepted-reference fixtures for each
named non-catch-all case and assert that the production boundary rejects them
while `everparse_boundary_generated_subset_applicable` is false.

## Production Gap

Phase 1 is not production-complete until one of these is true:

- the EverParse-generated grammar constructs full packets for every accepted
  production DNS packet shape, including compression and broader RR coverage; or
- the repository carries a proof-backed coexistence decision that keeps the
  handwritten parser as a verified reference construction layer behind a
  generated validator gate.

The current target policy uses the second option in narrow form: generated
validators gate the accepted wire shapes, while the handwritten parser still
constructs the packet value that downstream verified code consumes for those
covered shapes. The handwritten parser remains available as the
bootstrap/reference parser, but reference-only accepted shapes are no longer
accepted at the active production boundary.

## Serializer contract

`well_formed_record` ties RDLENGTH to actual bytes, bounds owner names, and checks
the parser's supported RDATA shapes. Compressed name-bearing RDATA is rejected
on serialization because its offsets cannot safely be relocated. Unknown and
other opaque RDATA types are not semantically interpreted.

`serialize_dns_packet_bytes` performs checked construction: success implies the
reference parser returns the exact input packet, proved by
`lemma_serialized_packet_roundtrip`. This adds a parse-back check and does not
establish completeness, optimality, or a generated-serializer implementation.

Remaining closure: a semantic success/failure refinement for the real generated
validator and its adapter, a grammar-wide name-offset correspondence proof,
typed relocation-safe RDATA, and full supported-domain completeness. These are
not supplied by more fixtures or by weakening the external interface to an axiom.

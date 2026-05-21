# Parser Equivalence Contract

This document records the current relationship between the handwritten DNS
parser and the EverParse-generated production-target boundary.

## Current Boundary

The active parser boundary is `EverParseGeneratedSubset` in
`DNS.Protocol.Parser.EverParseBoundary`. The boundary uses the generated-subset
classifier as the production acceptance gate. Packets inside the generated
subset are constructed through `parse_dns_packet_bytes_generated`, which still
uses the handwritten parser as the semantic construction layer. Packets outside
the generated subset are rejected by the production boundary even if the
handwritten reference parser can parse them.

The boundary contract is now:

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

The generated-subset accept/reject lemmas make the coexistence contract explicit
for packets covered by the generated validator gate. The shared fixture tests
also assert boundary/reference equality across the implemented valid and
malformed packet examples.

## Generated Subset

The generated validator gate is classified by `classify_generated_subset`.
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

The current production policy uses the second option in narrow form: generated
validators gate the accepted wire shapes, while the handwritten parser still
constructs the packet value that downstream verified code consumes for those
covered shapes. The handwritten parser remains available as the
bootstrap/reference parser, but reference-only accepted shapes are no longer
accepted at the active production boundary.

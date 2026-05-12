module DNS.Protocol.Parser.EverParseBoundary

open DNS.Protocol
open DNS.Protocol.Parser
open DNS.Protocol.Parser.EverParseGenerated

type parser_backend =
  | ReferenceBootstrap
  | EverParseGeneratedSubset
  | EverParseGenerated

let active_parser_backend : parser_backend = EverParseGeneratedSubset

let everparse_generated_parser_available : bool = false

let everparse_subset_boundary_available : bool = true

let everparse_3d_grammar_available_at_boundary : bool =
  everparse_3d_grammar_available

let everparse_generated_artifact_build_gate_available_at_boundary : bool =
  everparse_generated_artifact_build_gate_available

let everparse_generated_artifact_linked_in_adapter_verification_at_boundary : bool =
  everparse_generated_artifact_linked_in_adapter_verification

let everparse_generated_artifact_wired_into_active_parser_at_boundary : bool =
  everparse_generated_artifact_wired_into_active_parser

let everparse_generated_subset_gate_active_at_boundary : bool =
  everparse_generated_subset_gate_active

let everparse_generated_single_label_question_gate_active_at_boundary : bool =
  everparse_generated_single_label_question_gate_active

let everparse_generated_two_label_question_gate_active_at_boundary : bool =
  everparse_generated_two_label_question_gate_active

let everparse_generated_uncompressed_question_gate_active_at_boundary : bool =
  everparse_generated_uncompressed_question_gate_active

let everparse_generated_single_answer_rr_gate_active_at_boundary : bool =
  everparse_generated_single_answer_rr_gate_active

let everparse_generated_a_aaaa_answer_rr_gate_active_at_boundary : bool =
  everparse_generated_a_aaaa_answer_rr_gate_active

let everparse_generated_name_rdata_answer_rr_gate_active_at_boundary : bool =
  everparse_generated_name_rdata_answer_rr_gate_active

let everparse_generated_mx_answer_rr_gate_active_at_boundary : bool =
  everparse_generated_mx_answer_rr_gate_active

val parse_dns_packet_bytes_at_boundary :
  input:list FStar.UInt8.t ->
  Tot (option dns_packet)

let parse_dns_packet_bytes_at_boundary input =
  parse_dns_packet_bytes_generated input

val validate_dns_packet_bytes_at_boundary :
  input:list FStar.UInt8.t ->
  Tot bool

let validate_dns_packet_bytes_at_boundary input =
  match parse_dns_packet_bytes_at_boundary input with
  | Some _ -> true
  | None -> false

val lemma_boundary_matches_reference :
  input:list FStar.UInt8.t ->
  Lemma (ensures (parse_dns_packet_bytes_at_boundary input ==
                  parse_dns_packet_bytes input))

let lemma_boundary_matches_reference input =
  lemma_generated_matches_reference input

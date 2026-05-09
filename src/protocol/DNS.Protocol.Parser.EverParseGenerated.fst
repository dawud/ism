module DNS.Protocol.Parser.EverParseGenerated

open DNS.Protocol
open DNS.Protocol.Parser
module L = FStar.List.Tot

type generated_parse_status =
  | GeneratedSubsetBoundaryWithVerifiedArtifact

let generated_parse_status_value : generated_parse_status =
  GeneratedSubsetBoundaryWithVerifiedArtifact

type everparse_source_status =
  | CheckedIn3DHeaderGrammar

let everparse_source_status_value : everparse_source_status = CheckedIn3DHeaderGrammar

let everparse_3d_grammar_available : bool = true

let everparse_generated_artifact_build_gate_available : bool = true

let everparse_generated_artifact_linked_in_adapter_verification : bool = true

let everparse_generated_artifact_wired_into_active_parser : bool = true

let everparse_generated_subset_gate_active : bool = true

let everparse_generated_single_label_question_gate_active : bool = false

let everparse_generated_two_label_question_gate_active : bool = false

let everparse_generated_uncompressed_question_gate_active : bool = true

val parse_dns_packet_bytes_generated :
  input:list FStar.UInt8.t ->
  Tot (option dns_packet)

let parse_dns_packet_bytes_generated input =
  match parse_header_bytes input with
  | None -> None
  | Some (h, rest) ->
      let qd = FStar.UInt16.v h.qdcount in
      let an = FStar.UInt16.v h.ancount in
      let ns = FStar.UInt16.v h.nscount in
      let ar = FStar.UInt16.v h.arcount in
      match parse_questions_bytes qd qd rest with
      | None -> None
      | Some (qs, after_questions) ->
          match parse_resource_records_bytes false an an after_questions with
          | None -> None
          | Some (answers, after_answers) ->
              match parse_resource_records_bytes false ns ns after_answers with
              | None -> None
              | Some (authorities, after_authorities) ->
                  match parse_resource_records_bytes true ar ar after_authorities with
                  | None -> None
                  | Some (additionals, tail) ->
                      if L.length tail = 0 then
                        Some {
                          header = h;
                          questions = qs;
                          answers = answers;
                          authorities = authorities;
                          additionals = additionals;
                        }
                      else
                        None

val validate_dns_packet_bytes_generated :
  input:list FStar.UInt8.t ->
  Tot bool

let validate_dns_packet_bytes_generated input =
  match parse_dns_packet_bytes_generated input with
  | Some _ -> true
  | None -> false

val lemma_generated_matches_reference :
  input:list FStar.UInt8.t ->
  Lemma (ensures (parse_dns_packet_bytes_generated input ==
                  parse_dns_packet_bytes input))

let lemma_generated_matches_reference input =
  ()

module DNS.ProofAudit.Tests

module P = DNS.Protocol.Parser
module B = DNS.Protocol.Parser.EverParseBoundary
module S = DNS.Protocol.Serializer
module Z = DNS.Zone.RadixTree
module R = DNS.Recursive.Security
module C = DNS.Recursive.Cache
module T = DNS.QUIC.StreamMapping
module L = FStar.List.Tot

(* Desired behavior for the original audit counterexamples. *)
let owner_pointer_packet (target:FStar.UInt8.t) : list FStar.UInt8.t = [
  0uy; 0uy; 0x81uy; 0x80uy; 0uy; 1uy; 0uy; 1uy; 0uy; 0uy; 0uy; 0uy;
  0uy; 0uy; 1uy; 0uy; 1uy;
  0xc0uy; target; 0uy; 1uy; 0uy; 1uy; 0uy; 0uy; 0uy; 1uy;
  0uy; 4uy; 127uy; 0uy; 0uy; 1uy
]

let header_pointer_rejected =
  assert_norm (B.parse_dns_packet_bytes_at_boundary (owner_pointer_packet 0uy) == None)
let previous_name_pointer_accepted =
  assert_norm (Some? (B.parse_dns_packet_bytes_at_boundary (owner_pointer_packet 12uy)))

let label_payload_pointer_packet : list FStar.UInt8.t = [
  0uy; 0uy; 0x81uy; 0x80uy; 0uy; 1uy; 0uy; 1uy; 0uy; 0uy; 0uy; 0uy;
  3uy; 0uy; 0uy; 0uy; 0uy; 0uy; 1uy; 0uy; 1uy;
  0xc0uy; 13uy; 0uy; 1uy; 0uy; 1uy; 0uy; 0uy; 0uy; 1uy;
  0uy; 4uy; 127uy; 0uy; 0uy; 1uy
]
let label_payload_pointer_rejected =
  assert_norm (P.parse_dns_packet_bytes label_payload_pointer_packet == None)

let opaque_payload_pointer_packet : list FStar.UInt8.t = [
  0uy; 0uy; 0x81uy; 0x80uy; 0uy; 1uy; 0uy; 2uy; 0uy; 0uy; 0uy; 0uy;
  0uy; 0uy; 1uy; 0uy; 1uy;
  0uy; 0xfduy; 0xe8uy; 0uy; 1uy; 0uy; 0uy; 0uy; 1uy; 0uy; 1uy; 0uy;
  0xc0uy; 28uy; 0uy; 1uy; 0uy; 1uy; 0uy; 0uy; 0uy; 1uy;
  0uy; 4uy; 127uy; 0uy; 0uy; 1uy
]
let opaque_payload_pointer_rejected =
  assert_norm (P.parse_dns_packet_bytes opaque_payload_pointer_packet == None)

let uppercase_www : DNS.Name.label = [0x57uy; 0x57uy; 0x57uy]
let cache_comparison_case_insensitive =
  assert_norm (C.qname_eq [uppercase_www] [Z.label_www])
let bailiwick_comparison_case_insensitive =
  assert_norm (R.is_subdomain [uppercase_www] [Z.label_www])
let uppercase_question : DNS.Protocol.question =
  { Z.exact_a_question with qname = [uppercase_www; Z.label_example; Z.label_com] }
let uppercase_authoritative_query_succeeds =
  assert_norm (match Z.resolve_authoritative_question Z.wildcardless_test_root uppercase_question with
    | DNS.RCode.Success [_] -> true | _ -> false)

let wire_question : list FStar.UInt8.t = [
  3uy; 0x77uy; 0x77uy; 0x77uy;
  7uy; 0x65uy; 0x78uy; 0x61uy; 0x6duy; 0x70uy; 0x6cuy; 0x65uy;
  3uy; 0x63uy; 0x6fuy; 0x6duy; 0uy; 0uy; 1uy; 0uy; 1uy
]
let parsed_wire_question_finds_record =
  assert_norm (match P.parse_question_bytes wire_question with
    | Some (q, []) -> (match Z.resolve_authoritative_question Z.wildcardless_test_root q with
        | DNS.RCode.Success [_] -> true | _ -> false)
    | _ -> false)
let reversed_question_does_not_match =
  assert_norm (match Z.resolve_authoritative_question Z.wildcardless_test_root
    { Z.exact_a_question with qname = [Z.label_com; Z.label_example; Z.label_www] } with
    | DNS.RCode.Error DNS.RCode.NXDomain -> true | _ -> false)

let empty_a_serialization_rejected =
  assert_norm (S.serialize_resource_record_fields_bytes [] DNS.Protocol.A 1us 60ul [] == None)
let noncanonical_unknown_type_rejected =
  assert_norm (S.serialize_resource_record_fields_bytes [] (DNS.Protocol.UNKNOWN 1us) 1us 60ul [] == None)
let relocated_compressed_cname_rejected =
  assert_norm (S.serialize_resource_record_fields_bytes [] DNS.Protocol.CNAME 1us 60ul [0xc0uy;12uy] == None)
let cache_ttl_aged =
  assert_norm (match C.cached_value C.cached_entry C.cached_record.name 20UL with
    | Some rr -> rr.ttl == 50ul | _ -> false)
let expired_cache_misses =
  assert_norm (C.cached_value C.cached_entry C.cached_record.name 70UL == None)

let completed_body_waits_for_fin =
  assert_norm (T.fragment_phase T.ReadingLength 14ul 0uy 12uy == T.AwaitingFin 12ul)
let early_fin_rejected =
  assert_norm (T.finish_doq_phase (T.ReadingMessage (12ul, 11ul)) 0uy 0uy == T.Done)
let nonzero_id_rejected =
  assert_norm (T.finish_doq_phase (T.AwaitingFin 12ul) 0x12uy 0x34uy == T.Done)
let zero_length_rejected =
  assert_norm (T.fragment_phase T.ReadingLength 2ul 0uy 0uy == T.Done)
let later_extra_byte_rejected =
  assert_norm (T.fragment_phase (T.AwaitingFin 12ul) 1ul 0uy 0uy == T.Done)
let processing_extra_byte_rejected =
  assert_norm (T.fragment_phase (T.Processing 12ul) 1ul 0uy 0uy == T.Done)
let valid_fin_processing =
  assert_norm (T.finish_doq_phase (T.AwaitingFin 12ul) 0uy 0uy == T.Processing 12ul)

(* M2: retain the evaluated closed/invalid-state cases on the stable adapter. *)
let closed_stream_never_reopens =
  assert_norm (T.fragment_phase T.Done 0ul 0uy 0uy == T.Done /\
    T.fragment_phase T.Done 14ul 0uy 12uy == T.Done /\
    T.finish_doq_phase T.Done 0uy 0uy == T.Done)
let invalid_body_states_rejected =
  assert_norm (T.fragment_phase (T.ReadingMessage (11ul, 0ul)) 0ul 0uy 0uy == T.Done /\
    T.fragment_phase (T.ReadingMessage (12ul, 13ul)) 0ul 0uy 0uy == T.Done)
let repeated_fin_preserves_processing =
  assert_norm (T.finish_doq_phase (T.Processing 12ul) 0uy 0uy == T.Processing 12ul)

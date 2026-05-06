module DNS.Protocol.Parser.Tests

open FStar.UInt16
module L = FStar.List.Tot

open DNS.Protocol
open DNS.Protocol.Parser
open DNS.Protocol.Parser.EverParseBoundary

let valid_single_question_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy
  ]

let valid_single_question_dns_packet : dns_packet =
  {
    header = {
      id = 0x1234us;
      flags = uint16_to_flags 0x0100us;
      qdcount = 1us;
      ancount = 0us;
      nscount = 0us;
      arcount = 0us;
    };
    questions = [
      {
        qname = [];
        qtype = A;
        qclass = 1us;
      }
    ];
    answers = [];
    authorities = [];
    additionals = [];
  }

let valid_single_question_dns_query_test =
  assert_norm (parse_dns_packet_bytes valid_single_question_dns_query ==
               Some valid_single_question_dns_packet)

let truncated_dns_header : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy
  ]

let truncated_dns_header_parse_header_test =
  assert_norm (parse_header_bytes truncated_dns_header == None)

let truncated_dns_header_parse_packet_test =
  assert_norm (parse_dns_packet_bytes truncated_dns_header == None)

let truncated_qname_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x03uy; 0x77uy; 0x77uy
  ]

let truncated_qname_parse_question_test =
  assert_norm (parse_question_bytes [0x03uy; 0x77uy; 0x77uy] == None)

let truncated_qname_parse_packet_test =
  assert_norm (parse_dns_packet_bytes truncated_qname_dns_query == None)

let invalid_label_length_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x40uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy
  ]

let invalid_label_length_parse_question_test =
  assert_norm (parse_question_bytes [0x40uy; 0x00uy; 0x01uy; 0x00uy; 0x01uy] == None)

let invalid_label_length_parse_packet_test =
  assert_norm (parse_dns_packet_bytes invalid_label_length_dns_query == None)

let trailing_bytes_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0xffuy
  ]

let trailing_bytes_parse_packet_test =
  assert_norm (parse_dns_packet_bytes trailing_bytes_dns_query == None)

let nonzero_answer_count_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy
  ]

let nonzero_answer_count_parse_packet_test =
  assert_norm (parse_dns_packet_bytes nonzero_answer_count_dns_query == None)

let nonzero_authority_count_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy
  ]

let nonzero_authority_count_parse_packet_test =
  assert_norm (parse_dns_packet_bytes nonzero_authority_count_dns_query == None)

let nonzero_additional_count_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy
  ]

let nonzero_additional_count_parse_packet_test =
  assert_norm (parse_dns_packet_bytes nonzero_additional_count_dns_query == None)

let unknown_qtype_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0xffuy; 0xfeuy;
    0x00uy; 0x01uy
  ]

let unknown_qtype_dns_packet : dns_packet =
  {
    header = {
      id = 0x1234us;
      flags = uint16_to_flags 0x0100us;
      qdcount = 1us;
      ancount = 0us;
      nscount = 0us;
      arcount = 0us;
    };
    questions = [
      {
        qname = [];
        qtype = UNKNOWN 0xfffeus;
        qclass = 1us;
      }
    ];
    answers = [];
    authorities = [];
    additionals = [];
  }

let unknown_qtype_parse_packet_test =
  assert_norm (parse_dns_packet_bytes unknown_qtype_dns_query ==
               Some unknown_qtype_dns_packet)

let malformed_compression_pointer_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0xc0uy; 0x0cuy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy
  ]

let malformed_compression_pointer_parse_question_test =
  assert_norm (parse_question_bytes [0xc0uy; 0x0cuy; 0x00uy; 0x01uy; 0x00uy; 0x01uy] == None)

let malformed_compression_pointer_parse_packet_test =
  assert_norm (parse_dns_packet_bytes malformed_compression_pointer_dns_query == None)

let valid_single_answer_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x04uy;
    0x01uy; 0x02uy; 0x03uy; 0x04uy
  ]

let valid_single_answer_parse_packet_test =
  assert_norm (
    match parse_dns_packet_bytes valid_single_answer_dns_response with
    | Some p ->
        p.header.ancount == 1us /\
        L.length p.answers == 1 /\
        (match p.answers with
         | rr :: [] ->
             rr.rtype == A /\
             rr.rclass == 1us /\
             rr.ttl == 60ul /\
             rr.rdlen == 4us /\
             FStar.Bytes.length rr.rdata == 4
         | _ -> false)
    | None -> false)

let truncated_rr_header_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy
  ]

let truncated_rr_header_parse_packet_test =
  assert_norm (parse_dns_packet_bytes truncated_rr_header_dns_response == None)

let truncated_rdata_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x04uy;
    0x01uy; 0x02uy
  ]

let truncated_rdata_parse_packet_test =
  assert_norm (parse_dns_packet_bytes truncated_rdata_dns_response == None)

let unknown_rr_type_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0xffuy; 0xfeuy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x01uy;
    0x00uy; 0x02uy;
    0xabuy; 0xcduy
  ]

let unknown_rr_type_parse_packet_test =
  assert_norm (
    match parse_dns_packet_bytes unknown_rr_type_dns_response with
    | Some p ->
        L.length p.questions == 0 /\
        L.length p.answers == 1 /\
        (match p.answers with
         | rr :: [] ->
             rr.rtype == UNKNOWN 0xfffeus /\
             rr.rdlen == 2us /\
             FStar.Bytes.length rr.rdata == 2
         | _ -> false)
    | None -> false)

let invalid_a_rdata_length_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x03uy;
    0x01uy; 0x02uy; 0x03uy
  ]

let invalid_a_rdata_length_parse_packet_test =
  assert_norm (parse_dns_packet_bytes invalid_a_rdata_length_dns_response == None)

let invalid_aaaa_rdata_length_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x1cuy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x1cuy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x04uy;
    0x20uy; 0x01uy; 0x0duy; 0xb8uy
  ]

let invalid_aaaa_rdata_length_parse_packet_test =
  assert_norm (parse_dns_packet_bytes invalid_aaaa_rdata_length_dns_response == None)

let boundary_valid_single_question_dns_query_test =
  assert_norm (parse_dns_packet_bytes_at_boundary valid_single_question_dns_query ==
               parse_dns_packet_bytes valid_single_question_dns_query)

let boundary_truncated_dns_header_test =
  assert_norm (parse_dns_packet_bytes_at_boundary truncated_dns_header ==
               parse_dns_packet_bytes truncated_dns_header)

let boundary_truncated_qname_test =
  assert_norm (parse_dns_packet_bytes_at_boundary truncated_qname_dns_query ==
               parse_dns_packet_bytes truncated_qname_dns_query)

let boundary_invalid_label_length_test =
  assert_norm (parse_dns_packet_bytes_at_boundary invalid_label_length_dns_query ==
               parse_dns_packet_bytes invalid_label_length_dns_query)

let boundary_trailing_bytes_test =
  assert_norm (parse_dns_packet_bytes_at_boundary trailing_bytes_dns_query ==
               parse_dns_packet_bytes trailing_bytes_dns_query)

let boundary_rejects_malformed_answer_section_test =
  assert_norm (parse_dns_packet_bytes_at_boundary nonzero_answer_count_dns_query ==
               parse_dns_packet_bytes nonzero_answer_count_dns_query)

let boundary_rejects_malformed_authority_section_test =
  assert_norm (parse_dns_packet_bytes_at_boundary nonzero_authority_count_dns_query ==
               parse_dns_packet_bytes nonzero_authority_count_dns_query)

let boundary_rejects_malformed_additional_section_test =
  assert_norm (parse_dns_packet_bytes_at_boundary nonzero_additional_count_dns_query ==
               parse_dns_packet_bytes nonzero_additional_count_dns_query)

let boundary_accepts_unknown_qtype_test =
  assert_norm (parse_dns_packet_bytes_at_boundary unknown_qtype_dns_query ==
               parse_dns_packet_bytes unknown_qtype_dns_query)

let boundary_rejects_malformed_compression_pointer_test =
  assert_norm (parse_dns_packet_bytes_at_boundary malformed_compression_pointer_dns_query ==
               parse_dns_packet_bytes malformed_compression_pointer_dns_query)

let boundary_accepts_single_answer_test =
  assert_norm (parse_dns_packet_bytes_at_boundary valid_single_answer_dns_response ==
               parse_dns_packet_bytes valid_single_answer_dns_response)

let boundary_rejects_truncated_rr_header_test =
  assert_norm (parse_dns_packet_bytes_at_boundary truncated_rr_header_dns_response ==
               parse_dns_packet_bytes truncated_rr_header_dns_response)

let boundary_rejects_truncated_rdata_test =
  assert_norm (parse_dns_packet_bytes_at_boundary truncated_rdata_dns_response ==
               parse_dns_packet_bytes truncated_rdata_dns_response)

let boundary_accepts_unknown_rr_type_test =
  assert_norm (parse_dns_packet_bytes_at_boundary unknown_rr_type_dns_response ==
               parse_dns_packet_bytes unknown_rr_type_dns_response)

let boundary_rejects_invalid_a_rdata_length_test =
  assert_norm (parse_dns_packet_bytes_at_boundary invalid_a_rdata_length_dns_response ==
               parse_dns_packet_bytes invalid_a_rdata_length_dns_response)

let boundary_rejects_invalid_aaaa_rdata_length_test =
  assert_norm (parse_dns_packet_bytes_at_boundary invalid_aaaa_rdata_length_dns_response ==
               parse_dns_packet_bytes invalid_aaaa_rdata_length_dns_response)

let boundary_backend_status_test =
  assert_norm (active_parser_backend == EverParseGeneratedSubset /\
               everparse_subset_boundary_available == true /\
               everparse_generated_parser_available == false)

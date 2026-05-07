module DNS.Protocol.Parser.Tests

open FStar.UInt16
module L = FStar.List.Tot

open DNS.Protocol
open DNS.Protocol.Parser
open DNS.Protocol.Parser.EverParseBoundary
module OPT = DNS.Protocol.OPT

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

let valid_edns0_opt_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x29uy;
    0x04uy; 0xd0uy;
    0x00uy; 0x00uy; 0x00uy; 0x00uy;
    0x00uy; 0x00uy
  ]

let valid_edns0_opt_parse_packet_test =
  assert_norm (
    match parse_dns_packet_bytes valid_edns0_opt_dns_query with
    | Some p ->
        p.header.arcount == 1us /\
        L.length p.additionals == 1 /\
        (match p.additionals with
         | rr :: [] ->
             rr.name == [] /\
             rr.rtype == OPT /\
             rr.rclass == 1232us /\
             rr.ttl == 0ul /\
             rr.rdlen == 0us /\
             FStar.Bytes.length rr.rdata == 0
         | _ -> false)
    | None -> false)

let nonroot_edns0_opt_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x01uy;
    0x01uy; 0x78uy; 0x00uy;
    0x00uy; 0x29uy;
    0x04uy; 0xd0uy;
    0x00uy; 0x00uy; 0x00uy; 0x00uy;
    0x00uy; 0x00uy
  ]

let nonroot_edns0_opt_parse_packet_test =
  assert_norm (parse_dns_packet_bytes nonroot_edns0_opt_dns_query == None)

let unsupported_edns_version_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x29uy;
    0x04uy; 0xd0uy;
    0x00uy; 0x01uy; 0x00uy; 0x00uy;
    0x00uy; 0x00uy
  ]

let unsupported_edns_version_parse_packet_test =
  assert_norm (parse_dns_packet_bytes unsupported_edns_version_dns_query == None)

let edns0_padding_option_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x29uy;
    0x04uy; 0xd0uy;
    0x00uy; 0x00uy; 0x00uy; 0x00uy;
    0x00uy; 0x08uy;
    0x00uy; 0x0cuy;
    0x00uy; 0x04uy;
    0x00uy; 0x00uy; 0x00uy; 0x00uy
  ]

let edns0_padding_option_parse_packet_test =
  assert_norm (
    match parse_dns_packet_bytes edns0_padding_option_dns_query with
    | Some p ->
        L.length p.additionals == 1 /\
        (match p.additionals with
         | rr :: [] ->
             rr.rtype == OPT /\
             rr.rdlen == 8us /\
             FStar.Bytes.length rr.rdata == 8
         | _ -> false)
    | None -> false)

let edns0_unknown_option_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x29uy;
    0x04uy; 0xd0uy;
    0x00uy; 0x00uy; 0x00uy; 0x00uy;
    0x00uy; 0x06uy;
    0xfduy; 0xe8uy;
    0x00uy; 0x02uy;
    0xabuy; 0xcduy
  ]

let edns0_unknown_option_parse_packet_test =
  assert_norm (match parse_dns_packet_bytes edns0_unknown_option_dns_query with
               | Some _ -> true
               | None -> false)

let edns0_unknown_option_preserved_test =
  assert_norm (
    match OPT.parse_edns_options_bytes 6 [0xfduy; 0xe8uy; 0x00uy; 0x02uy; 0xabuy; 0xcduy] with
    | Some (opt :: []) ->
        opt.code == 65000us /\
        opt.len == 2us /\
        FStar.Bytes.length opt.data == 2
    | _ -> false)

let truncated_edns_option_header_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x29uy;
    0x04uy; 0xd0uy;
    0x00uy; 0x00uy; 0x00uy; 0x00uy;
    0x00uy; 0x03uy;
    0x00uy; 0x0cuy; 0x00uy
  ]

let truncated_edns_option_header_parse_packet_test =
  assert_norm (parse_dns_packet_bytes truncated_edns_option_header_dns_query == None)

let truncated_edns_option_data_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x29uy;
    0x04uy; 0xd0uy;
    0x00uy; 0x00uy; 0x00uy; 0x00uy;
    0x00uy; 0x06uy;
    0x00uy; 0x0cuy;
    0x00uy; 0x04uy;
    0x00uy; 0x00uy
  ]

let truncated_edns_option_data_parse_packet_test =
  assert_norm (parse_dns_packet_bytes truncated_edns_option_data_dns_query == None)

let valid_cname_rdata_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x05uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x05uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x07uy;
    0x05uy; 0x61uy; 0x6cuy; 0x69uy; 0x61uy; 0x73uy; 0x00uy
  ]

let valid_cname_rdata_parse_packet_test =
  assert_norm (
    match parse_dns_packet_bytes valid_cname_rdata_dns_response with
    | Some p ->
        L.length p.answers == 1 /\
        (match p.answers with
         | rr :: [] ->
             rr.rtype == CNAME /\
             rr.rdlen == 7us /\
             FStar.Bytes.length rr.rdata == 7
         | _ -> false)
    | None -> false)

let truncated_name_rdata_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x05uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x05uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x03uy;
    0x05uy; 0x61uy; 0x6cuy
  ]

let truncated_name_rdata_parse_packet_test =
  assert_norm (parse_dns_packet_bytes truncated_name_rdata_dns_response == None)

let trailing_name_rdata_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x05uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x05uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x02uy;
    0x00uy; 0xffuy
  ]

let trailing_name_rdata_parse_packet_test =
  assert_norm (parse_dns_packet_bytes trailing_name_rdata_dns_response == None)

let compressed_name_rdata_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x05uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x05uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x02uy;
    0xc0uy; 0x0cuy
  ]

let compressed_name_rdata_parse_packet_test =
  assert_norm (parse_dns_packet_bytes compressed_name_rdata_dns_response == None)

let valid_mx_rdata_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x0fuy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x0fuy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x08uy;
    0x00uy; 0x0auy;
    0x04uy; 0x6duy; 0x61uy; 0x69uy; 0x6cuy; 0x00uy
  ]

let valid_mx_rdata_parse_packet_test =
  assert_norm (
    match parse_dns_packet_bytes valid_mx_rdata_dns_response with
    | Some p ->
        L.length p.answers == 1 /\
        (match p.answers with
         | rr :: [] ->
             rr.rtype == MX /\
             rr.rdlen == 8us /\
             FStar.Bytes.length rr.rdata == 8
         | _ -> false)
    | None -> false)

let truncated_mx_preference_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x0fuy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x0fuy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x01uy;
    0x00uy
  ]

let truncated_mx_preference_parse_packet_test =
  assert_norm (parse_dns_packet_bytes truncated_mx_preference_dns_response == None)

let truncated_mx_exchange_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x0fuy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x0fuy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x05uy;
    0x00uy; 0x0auy;
    0x04uy; 0x6duy; 0x61uy
  ]

let truncated_mx_exchange_parse_packet_test =
  assert_norm (parse_dns_packet_bytes truncated_mx_exchange_dns_response == None)

let trailing_mx_exchange_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x0fuy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x0fuy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x04uy;
    0x00uy; 0x0auy;
    0x00uy; 0xffuy
  ]

let trailing_mx_exchange_parse_packet_test =
  assert_norm (parse_dns_packet_bytes trailing_mx_exchange_dns_response == None)

let compressed_mx_exchange_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x0fuy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x0fuy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x04uy;
    0x00uy; 0x0auy;
    0xc0uy; 0x0cuy
  ]

let compressed_mx_exchange_parse_packet_test =
  assert_norm (parse_dns_packet_bytes compressed_mx_exchange_dns_response == None)

let valid_soa_rdata_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x06uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x06uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x1euy;
    0x02uy; 0x6euy; 0x73uy; 0x00uy;
    0x04uy; 0x68uy; 0x6fuy; 0x73uy; 0x74uy; 0x00uy;
    0x00uy; 0x00uy; 0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x02uy;
    0x00uy; 0x00uy; 0x00uy; 0x03uy;
    0x00uy; 0x00uy; 0x00uy; 0x04uy;
    0x00uy; 0x00uy; 0x00uy; 0x05uy
  ]

let valid_soa_rdata_parse_packet_test =
  assert_norm (
    match parse_dns_packet_bytes valid_soa_rdata_dns_response with
    | Some p ->
        L.length p.answers == 1 /\
        (match p.answers with
         | rr :: [] ->
             rr.rtype == SOA /\
             rr.rdlen == 30us /\
             FStar.Bytes.length rr.rdata == 30
         | _ -> false)
    | None -> false)

let truncated_soa_mname_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x06uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x06uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x03uy;
    0x02uy; 0x6euy; 0x73uy
  ]

let truncated_soa_mname_parse_packet_test =
  assert_norm (parse_dns_packet_bytes truncated_soa_mname_dns_response == None)

let trailing_soa_timers_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x06uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x06uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x17uy;
    0x00uy;
    0x00uy;
    0x00uy; 0x00uy; 0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x02uy;
    0x00uy; 0x00uy; 0x00uy; 0x03uy;
    0x00uy; 0x00uy; 0x00uy; 0x04uy;
    0x00uy; 0x00uy; 0x00uy; 0x05uy;
    0xffuy
  ]

let trailing_soa_timers_parse_packet_test =
  assert_norm (parse_dns_packet_bytes trailing_soa_timers_dns_response == None)

let compressed_soa_mname_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x06uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x06uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x16uy;
    0xc0uy; 0x0cuy;
    0x00uy; 0x00uy; 0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x02uy;
    0x00uy; 0x00uy; 0x00uy; 0x03uy;
    0x00uy; 0x00uy; 0x00uy; 0x04uy;
    0x00uy; 0x00uy; 0x00uy; 0x05uy
  ]

let compressed_soa_mname_parse_packet_test =
  assert_norm (parse_dns_packet_bytes compressed_soa_mname_dns_response == None)

let valid_txt_rdata_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x10uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x10uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x08uy;
    0x03uy; 0x66uy; 0x6fuy; 0x6fuy;
    0x03uy; 0x62uy; 0x61uy; 0x72uy
  ]

let valid_txt_rdata_parse_packet_test =
  assert_norm (
    match parse_dns_packet_bytes valid_txt_rdata_dns_response with
    | Some p ->
        L.length p.answers == 1 /\
        (match p.answers with
         | rr :: [] ->
             rr.rtype == TXT /\
             rr.rdlen == 8us /\
             FStar.Bytes.length rr.rdata == 8
         | _ -> false)
    | None -> false)

let empty_txt_string_rdata_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x10uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x10uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x01uy;
    0x00uy
  ]

let empty_txt_string_rdata_parse_packet_test =
  assert_norm (
    match parse_dns_packet_bytes empty_txt_string_rdata_dns_response with
    | Some p ->
        L.length p.answers == 1 /\
        (match p.answers with
         | rr :: [] ->
             rr.rtype == TXT /\
             rr.rdlen == 1us /\
             FStar.Bytes.length rr.rdata == 1
         | _ -> false)
    | None -> false)

let zero_length_txt_rdata_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x10uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x10uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x00uy
  ]

let zero_length_txt_rdata_parse_packet_test =
  assert_norm (parse_dns_packet_bytes zero_length_txt_rdata_dns_response == None)

let truncated_txt_string_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x10uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x10uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x04uy;
    0x05uy; 0x66uy; 0x6fuy; 0x6fuy
  ]

let truncated_txt_string_parse_packet_test =
  assert_norm (parse_dns_packet_bytes truncated_txt_string_dns_response == None)

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

let boundary_accepts_edns0_opt_test =
  assert_norm (parse_dns_packet_bytes_at_boundary valid_edns0_opt_dns_query ==
               parse_dns_packet_bytes valid_edns0_opt_dns_query)

let boundary_rejects_nonroot_edns0_opt_test =
  assert_norm (parse_dns_packet_bytes_at_boundary nonroot_edns0_opt_dns_query ==
               parse_dns_packet_bytes nonroot_edns0_opt_dns_query)

let boundary_rejects_unsupported_edns_version_test =
  assert_norm (parse_dns_packet_bytes_at_boundary unsupported_edns_version_dns_query ==
               parse_dns_packet_bytes unsupported_edns_version_dns_query)

let boundary_accepts_edns0_padding_option_test =
  assert_norm (parse_dns_packet_bytes_at_boundary edns0_padding_option_dns_query ==
               parse_dns_packet_bytes edns0_padding_option_dns_query)

let boundary_accepts_edns0_unknown_option_test =
  assert_norm (parse_dns_packet_bytes_at_boundary edns0_unknown_option_dns_query ==
               parse_dns_packet_bytes edns0_unknown_option_dns_query)

let boundary_rejects_truncated_edns_option_header_test =
  assert_norm (parse_dns_packet_bytes_at_boundary truncated_edns_option_header_dns_query ==
               parse_dns_packet_bytes truncated_edns_option_header_dns_query)

let boundary_rejects_truncated_edns_option_data_test =
  assert_norm (parse_dns_packet_bytes_at_boundary truncated_edns_option_data_dns_query ==
               parse_dns_packet_bytes truncated_edns_option_data_dns_query)

let boundary_accepts_cname_rdata_test =
  assert_norm (parse_dns_packet_bytes_at_boundary valid_cname_rdata_dns_response ==
               parse_dns_packet_bytes valid_cname_rdata_dns_response)

let boundary_rejects_truncated_name_rdata_test =
  assert_norm (parse_dns_packet_bytes_at_boundary truncated_name_rdata_dns_response ==
               parse_dns_packet_bytes truncated_name_rdata_dns_response)

let boundary_rejects_trailing_name_rdata_test =
  assert_norm (parse_dns_packet_bytes_at_boundary trailing_name_rdata_dns_response ==
               parse_dns_packet_bytes trailing_name_rdata_dns_response)

let boundary_rejects_compressed_name_rdata_test =
  assert_norm (parse_dns_packet_bytes_at_boundary compressed_name_rdata_dns_response ==
               parse_dns_packet_bytes compressed_name_rdata_dns_response)

let boundary_accepts_mx_rdata_test =
  assert_norm (parse_dns_packet_bytes_at_boundary valid_mx_rdata_dns_response ==
               parse_dns_packet_bytes valid_mx_rdata_dns_response)

let boundary_rejects_truncated_mx_preference_test =
  assert_norm (parse_dns_packet_bytes_at_boundary truncated_mx_preference_dns_response ==
               parse_dns_packet_bytes truncated_mx_preference_dns_response)

let boundary_rejects_truncated_mx_exchange_test =
  assert_norm (parse_dns_packet_bytes_at_boundary truncated_mx_exchange_dns_response ==
               parse_dns_packet_bytes truncated_mx_exchange_dns_response)

let boundary_rejects_trailing_mx_exchange_test =
  assert_norm (parse_dns_packet_bytes_at_boundary trailing_mx_exchange_dns_response ==
               parse_dns_packet_bytes trailing_mx_exchange_dns_response)

let boundary_rejects_compressed_mx_exchange_test =
  assert_norm (parse_dns_packet_bytes_at_boundary compressed_mx_exchange_dns_response ==
               parse_dns_packet_bytes compressed_mx_exchange_dns_response)

let boundary_accepts_soa_rdata_test =
  assert_norm (parse_dns_packet_bytes_at_boundary valid_soa_rdata_dns_response ==
               parse_dns_packet_bytes valid_soa_rdata_dns_response)

let boundary_rejects_truncated_soa_mname_test =
  assert_norm (parse_dns_packet_bytes_at_boundary truncated_soa_mname_dns_response ==
               parse_dns_packet_bytes truncated_soa_mname_dns_response)

let boundary_rejects_trailing_soa_timers_test =
  assert_norm (parse_dns_packet_bytes_at_boundary trailing_soa_timers_dns_response ==
               parse_dns_packet_bytes trailing_soa_timers_dns_response)

let boundary_rejects_compressed_soa_mname_test =
  assert_norm (parse_dns_packet_bytes_at_boundary compressed_soa_mname_dns_response ==
               parse_dns_packet_bytes compressed_soa_mname_dns_response)

let boundary_accepts_txt_rdata_test =
  assert_norm (parse_dns_packet_bytes_at_boundary valid_txt_rdata_dns_response ==
               parse_dns_packet_bytes valid_txt_rdata_dns_response)

let boundary_accepts_empty_txt_string_rdata_test =
  assert_norm (parse_dns_packet_bytes_at_boundary empty_txt_string_rdata_dns_response ==
               parse_dns_packet_bytes empty_txt_string_rdata_dns_response)

let boundary_rejects_zero_length_txt_rdata_test =
  assert_norm (parse_dns_packet_bytes_at_boundary zero_length_txt_rdata_dns_response ==
               parse_dns_packet_bytes zero_length_txt_rdata_dns_response)

let boundary_rejects_truncated_txt_string_test =
  assert_norm (parse_dns_packet_bytes_at_boundary truncated_txt_string_dns_response ==
               parse_dns_packet_bytes truncated_txt_string_dns_response)

let boundary_backend_status_test =
  assert_norm (active_parser_backend == EverParseGeneratedSubset /\
               everparse_subset_boundary_available == true /\
               everparse_generated_parser_available == false)

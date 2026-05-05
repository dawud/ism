module DNS.Protocol.Parser.Tests

open FStar.UInt16
module L = FStar.List.Tot

open DNS.Protocol
open DNS.Protocol.Parser

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

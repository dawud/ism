module DNS.Protocol.Parser.Tests

open FStar.UInt16
module L = FStar.List.Tot

open DNS.Protocol
open DNS.Protocol.Parser
open DNS.Protocol.Parser.EverParseBoundary
module OPT = DNS.Protocol.OPT
module SER = DNS.Protocol.Serializer

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

let valid_single_label_question_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x35uy;
    0x01uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x01uy; 0x61uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy
  ]

let valid_single_label_question_dns_packet : dns_packet =
  {
    header = {
      id = 0x1235us;
      flags = uint16_to_flags 0x0100us;
      qdcount = 1us;
      ancount = 0us;
      nscount = 0us;
      arcount = 0us;
    };
    questions = [
      {
        qname = [[0x61uy]];
        qtype = A;
        qclass = 1us;
      }
    ];
    answers = [];
    authorities = [];
    additionals = [];
  }

let valid_two_label_question_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x36uy;
    0x01uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x03uy; 0x77uy; 0x77uy; 0x77uy;
    0x07uy; 0x65uy; 0x78uy; 0x61uy; 0x6duy; 0x70uy; 0x6cuy; 0x65uy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy
  ]

let valid_two_label_question_dns_packet : dns_packet =
  {
    header = {
      id = 0x1236us;
      flags = uint16_to_flags 0x0100us;
      qdcount = 1us;
      ancount = 0us;
      nscount = 0us;
      arcount = 0us;
    };
    questions = [
      {
        qname = [
          [0x77uy; 0x77uy; 0x77uy];
          [0x65uy; 0x78uy; 0x61uy; 0x6duy; 0x70uy; 0x6cuy; 0x65uy]
        ];
        qtype = A;
        qclass = 1us;
      }
    ];
    answers = [];
    authorities = [];
    additionals = [];
  }

let valid_three_label_question_dns_query : list FStar.UInt8.t =
  [
    0x12uy; 0x37uy;
    0x01uy; 0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x03uy; 0x77uy; 0x77uy; 0x77uy;
    0x07uy; 0x65uy; 0x78uy; 0x61uy; 0x6duy; 0x70uy; 0x6cuy; 0x65uy;
    0x03uy; 0x63uy; 0x6fuy; 0x6duy;
    0x00uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy
  ]

let valid_three_label_question_dns_packet : dns_packet =
  {
    header = {
      id = 0x1237us;
      flags = uint16_to_flags 0x0100us;
      qdcount = 1us;
      ancount = 0us;
      nscount = 0us;
      arcount = 0us;
    };
    questions = [
      {
        qname = [
          [0x77uy; 0x77uy; 0x77uy];
          [0x65uy; 0x78uy; 0x61uy; 0x6duy; 0x70uy; 0x6cuy; 0x65uy];
          [0x63uy; 0x6fuy; 0x6duy]
        ];
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

let valid_single_label_question_dns_query_test =
  assert_norm (parse_dns_packet_bytes valid_single_label_question_dns_query ==
               Some valid_single_label_question_dns_packet)

let valid_two_label_question_dns_query_test =
  assert_norm (parse_dns_packet_bytes valid_two_label_question_dns_query ==
               Some valid_two_label_question_dns_packet)

let valid_three_label_question_dns_query_test =
  assert_norm (parse_dns_packet_bytes valid_three_label_question_dns_query ==
               Some valid_three_label_question_dns_packet)

let generated_uncompressed_question_gate_accepts_root_test =
  assert_norm (generated_uncompressed_question_subset_applicable valid_single_question_dns_query == true)

let generated_uncompressed_question_gate_accepts_single_label_test =
  assert_norm (generated_uncompressed_question_subset_applicable valid_single_label_question_dns_query == true)

let generated_uncompressed_question_gate_accepts_two_label_test =
  assert_norm (generated_uncompressed_question_subset_applicable valid_two_label_question_dns_query == true)

let generated_uncompressed_question_gate_accepts_three_label_test =
  assert_norm (generated_uncompressed_question_subset_applicable valid_three_label_question_dns_query == true)

let serialized_response_header : header =
  {
    id = 0x1234us;
    flags = uint16_to_flags 0x8180us;
    qdcount = 0us;
    ancount = 0us;
    nscount = 0us;
    arcount = 0us;
  }

let serialized_response_header_bytes_test =
  assert_norm (SER.serialize_header_bytes serialized_response_header ==
               [
                 0x12uy; 0x34uy;
                 0x81uy; 0x80uy;
                 0x00uy; 0x00uy;
                 0x00uy; 0x00uy;
                 0x00uy; 0x00uy;
                 0x00uy; 0x00uy
               ])

let serialized_empty_response_parse_packet_test =
  assert_norm (
    match parse_dns_packet_bytes (SER.serialize_header_bytes serialized_response_header) with
    | Some p ->
        p.header.id == 0x1234us /\
        p.header.flags.qr == true /\
        p.header.flags.rcode == 0us /\
        L.length p.questions == 0 /\
        L.length p.answers == 0 /\
        L.length p.additionals == 0
    | None -> false)

let serialized_root_question_bytes_test =
  assert_norm (
    SER.serialize_question_bytes {
      qname = [];
      qtype = A;
      qclass = 1us;
    } == Some [0x00uy; 0x00uy; 0x01uy; 0x00uy; 0x01uy])

let serialized_a_answer_bytes : list FStar.UInt8.t =
  match SER.serialize_resource_record_fields_bytes
          []
          A
          1us
          60ul
          [0x01uy; 0x02uy; 0x03uy; 0x04uy] with
  | Some bytes -> bytes
  | None -> []

let serialized_a_answer_bytes_test =
  assert_norm (serialized_a_answer_bytes ==
               [
                 0x00uy;
                 0x00uy; 0x01uy;
                 0x00uy; 0x01uy;
                 0x00uy; 0x00uy; 0x00uy; 0x3cuy;
                 0x00uy; 0x04uy;
                 0x01uy; 0x02uy; 0x03uy; 0x04uy
               ])

let serialized_a_answer_response : list FStar.UInt8.t =
  L.append
    (SER.serialize_header_bytes {
      id = 0x1234us;
      flags = uint16_to_flags 0x8180us;
      qdcount = 0us;
      ancount = 1us;
      nscount = 0us;
      arcount = 0us;
    })
    serialized_a_answer_bytes

let serialized_a_answer_parse_packet_test =
  assert_norm (
    match parse_dns_packet_bytes serialized_a_answer_response with
    | Some p ->
        L.length p.answers == 1 /\
        (match p.answers with
         | rr :: [] ->
             rr.rtype == A /\
             rr.rdlen == 4us /\
             FStar.Bytes.length rr.rdata == 4
         | _ -> false)
    | None -> false)

let serialized_padding_opt_response_header : header =
  {
    id = 0x1234us;
    flags = uint16_to_flags 0x8180us;
    qdcount = 0us;
    ancount = 0us;
    nscount = 0us;
    arcount = 1us;
  }

let serialized_padding_opt_response_bytes : list FStar.UInt8.t =
  let flags:OPT.opt_flags = { do_bit = false; z = 0us } in
  match SER.serialize_response_with_opt_payload
          serialized_padding_opt_response_header
          1232us
          0uy
          0uy
          flags
          (OPT.serialize_padding_option_bytes 4us) with
  | Some bytes -> bytes
  | None -> []

let serialized_padding_opt_response_bytes_test =
  assert_norm (serialized_padding_opt_response_bytes ==
               [
                 0x12uy; 0x34uy;
                 0x81uy; 0x80uy;
                 0x00uy; 0x00uy;
                 0x00uy; 0x00uy;
                 0x00uy; 0x00uy;
                 0x00uy; 0x01uy;
                 0x00uy;
                 0x00uy; 0x29uy;
                 0x04uy; 0xd0uy;
                 0x00uy; 0x00uy; 0x00uy; 0x00uy;
                 0x00uy; 0x08uy;
                 0x00uy; 0x0cuy;
                 0x00uy; 0x04uy;
                 0x00uy; 0x00uy; 0x00uy; 0x00uy
               ])

let serialized_padding_opt_response_parse_packet_test =
  assert_norm (
    match parse_dns_packet_bytes serialized_padding_opt_response_bytes with
    | Some p ->
        L.length p.additionals == 1 /\
        (match p.additionals with
         | rr :: [] ->
             rr.rtype == OPT /\
             rr.rdlen == 8us /\
             FStar.Bytes.length rr.rdata == 8
         | _ -> false)
    | None -> false)

let serialized_single_question_packet_bytes : list FStar.UInt8.t =
  match SER.serialize_dns_packet_bytes valid_single_question_dns_packet with
  | Some bytes -> bytes
  | None -> []

let serialized_single_question_packet_bytes_test =
  assert_norm (serialized_single_question_packet_bytes == valid_single_question_dns_query)

let serialized_single_question_packet_roundtrip_test =
  assert_norm (parse_dns_packet_bytes serialized_single_question_packet_bytes ==
               Some valid_single_question_dns_packet)

let serialized_unknown_answer_packet : dns_packet =
  {
    header = {
      id = 0x1234us;
      flags = uint16_to_flags 0x8180us;
      qdcount = 0us;
      ancount = 1us;
      nscount = 0us;
      arcount = 0us;
    };
    questions = [];
    answers = [
      {
        name = [];
        rtype = UNKNOWN 65000us;
        rclass = 1us;
        ttl = 60ul;
        rdlen = 0us;
        rdata = FStar.Bytes.empty_bytes;
      }
    ];
    authorities = [];
    additionals = [];
  }

let serialized_unknown_answer_packet_serialize_test =
  assert_norm (
    match SER.serialize_dns_packet_bytes serialized_unknown_answer_packet with
    | Some _ -> true
    | None -> false)

let serialized_padding_opt_packet : dns_packet =
  {
    header = serialized_padding_opt_response_header;
    questions = [];
    answers = [];
    authorities = [];
    additionals = [
      {
        name = [];
        rtype = OPT;
        rclass = 1232us;
        ttl = 0ul;
        rdlen = 0us;
        rdata = FStar.Bytes.empty_bytes;
      }
    ];
  }

let serialized_empty_opt_packet_serialize_test =
  assert_norm (
    match SER.serialize_dns_packet_bytes serialized_padding_opt_packet with
    | Some _ -> true
    | None -> false)

let mismatched_count_packet : dns_packet =
  {
    header = {
      id = 0x1234us;
      flags = uint16_to_flags 0x8180us;
      qdcount = 1us;
      ancount = 0us;
      nscount = 0us;
      arcount = 0us;
    };
    questions = [];
    answers = [];
    authorities = [];
    additionals = [];
  }

let mismatched_count_packet_serialize_test =
  assert_norm (SER.serialize_dns_packet_bytes mismatched_count_packet == None)

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

let generated_single_answer_rr_gate_accepts_valid_single_answer_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      valid_single_answer_dns_response == true)

let valid_compressed_answer_name_dns_response : list FStar.UInt8.t =
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
    0xc0uy; 0x0cuy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x04uy;
    0x01uy; 0x02uy; 0x03uy; 0x04uy
  ]

let valid_compressed_answer_name_parse_packet_test =
  assert_norm (
    match parse_dns_packet_bytes valid_compressed_answer_name_dns_response with
    | Some p ->
        p.header.ancount == 1us /\
        L.length p.answers == 1 /\
        (match p.answers with
         | rr :: [] ->
             rr.name == [] /\
             rr.rtype == A /\
             rr.rdlen == 4us /\
             FStar.Bytes.length rr.rdata == 4
         | _ -> false)
    | None -> false)

let self_loop_compressed_answer_name_dns_response : list FStar.UInt8.t =
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
    0xc0uy; 0x11uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x04uy;
    0x01uy; 0x02uy; 0x03uy; 0x04uy
  ]

let self_loop_compressed_answer_name_parse_packet_test =
  assert_norm (parse_dns_packet_bytes self_loop_compressed_answer_name_dns_response == None)

let out_of_range_compressed_answer_name_dns_response : list FStar.UInt8.t =
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
    0xc0uy; 0xffuy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x04uy;
    0x01uy; 0x02uy; 0x03uy; 0x04uy
  ]

let out_of_range_compressed_answer_name_parse_packet_test =
  assert_norm (parse_dns_packet_bytes out_of_range_compressed_answer_name_dns_response == None)

let valid_aaaa_answer_dns_response : list FStar.UInt8.t =
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
    0x00uy; 0x10uy;
    0x20uy; 0x01uy; 0x0duy; 0xb8uy;
    0x00uy; 0x00uy; 0x00uy; 0x00uy;
    0x00uy; 0x00uy; 0x00uy; 0x00uy;
    0x00uy; 0x00uy; 0x00uy; 0x01uy
  ]

let valid_aaaa_answer_parse_packet_test =
  assert_norm (
    match parse_dns_packet_bytes valid_aaaa_answer_dns_response with
    | Some p ->
        p.header.ancount == 1us /\
        L.length p.answers == 1 /\
        (match p.answers with
         | rr :: [] ->
             rr.rtype == AAAA /\
             rr.rclass == 1us /\
             rr.ttl == 60ul /\
             rr.rdlen == 16us /\
             FStar.Bytes.length rr.rdata == 16
         | _ -> false)
    | None -> false)

let generated_aaaa_answer_gate_accepts_valid_aaaa_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      valid_aaaa_answer_dns_response == true)

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

let generated_a_answer_gate_covers_invalid_length_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      invalid_a_rdata_length_dns_response == true)

let generated_aaaa_answer_gate_covers_invalid_length_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      invalid_aaaa_rdata_length_dns_response == true)

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

let serialized_unknown_edns_option_bytes : list FStar.UInt8.t =
  let opt:OPT.edns_option = {
    code = 65000us;
    len = 0us;
    data = FStar.Bytes.empty_bytes;
  } in
  OPT.serialize_edns_option_bytes opt

let serialized_unknown_edns_option_bytes_test =
  assert_norm (serialized_unknown_edns_option_bytes ==
               [0xfduy; 0xe8uy; 0x00uy; 0x00uy])

let serialized_unknown_edns_option_roundtrip_test =
  assert_norm (
    match OPT.parse_edns_options_bytes 4 serialized_unknown_edns_option_bytes with
    | Some (opt :: []) ->
        opt.code == 65000us /\
        opt.len == 0us /\
        FStar.Bytes.length opt.data == 0
    | _ -> false)

let serialized_padding_option_for_block_bytes : list FStar.UInt8.t =
  match OPT.serialize_padding_option_for_block 10ul 16ul with
  | Some bytes -> bytes
  | None -> []

let serialized_padding_option_for_block_test =
  assert_norm (serialized_padding_option_for_block_bytes ==
               [0x00uy; 0x0cuy; 0x00uy; 0x02uy; 0x00uy; 0x00uy])

let serialized_padding_option_zero_block_test =
  assert_norm (OPT.serialize_padding_option_for_block 10ul 0ul == Some [])

let serialized_padding_opt_payload : list FStar.UInt8.t =
  OPT.serialize_padding_option_bytes 4us

let serialized_padding_opt_rr_bytes : list FStar.UInt8.t =
  let flags:OPT.opt_flags = { do_bit = false; z = 0us } in
  match OPT.serialize_opt_rr_bytes_with_payload
          1232us
          0uy
          0uy
          flags
          serialized_padding_opt_payload with
  | Some bytes -> bytes
  | None -> []

let serialized_padding_opt_rr_bytes_test =
  assert_norm (serialized_padding_opt_rr_bytes ==
               [
                 0x00uy;
                 0x00uy; 0x29uy;
                 0x04uy; 0xd0uy;
                 0x00uy; 0x00uy; 0x00uy; 0x00uy;
                 0x00uy; 0x08uy;
                 0x00uy; 0x0cuy;
                 0x00uy; 0x04uy;
                 0x00uy; 0x00uy; 0x00uy; 0x00uy
               ])

let serialized_padding_opt_dns_query : list FStar.UInt8.t =
  L.append [
    0x12uy; 0x34uy;
    0x01uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy; 0x01uy
  ] serialized_padding_opt_rr_bytes

let serialized_padding_opt_parse_packet_test =
  assert_norm (
    match parse_dns_packet_bytes serialized_padding_opt_dns_query with
    | Some p ->
        L.length p.additionals == 1 /\
        (match p.additionals with
         | rr :: [] ->
             rr.rtype == OPT /\
             rr.rdlen == 8us /\
             FStar.Bytes.length rr.rdata == 8
         | _ -> false)
    | None -> false)

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

let generated_name_rdata_answer_gate_accepts_valid_cname_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      valid_cname_rdata_dns_response == true)

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

let generated_name_rdata_answer_gate_covers_truncated_name_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      truncated_name_rdata_dns_response == true)

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

let generated_name_rdata_answer_gate_covers_trailing_name_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      trailing_name_rdata_dns_response == true)

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

let generated_name_rdata_answer_gate_covers_compressed_name_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      compressed_name_rdata_dns_response == true)

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

let generated_mx_answer_gate_accepts_valid_mx_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      valid_mx_rdata_dns_response == true)

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

let generated_mx_answer_gate_covers_truncated_preference_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      truncated_mx_preference_dns_response == true)

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

let generated_mx_answer_gate_covers_truncated_exchange_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      truncated_mx_exchange_dns_response == true)

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

let generated_mx_answer_gate_covers_trailing_exchange_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      trailing_mx_exchange_dns_response == true)

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

let generated_mx_answer_gate_covers_compressed_exchange_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      compressed_mx_exchange_dns_response == true)

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

let generated_soa_answer_gate_accepts_valid_soa_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      valid_soa_rdata_dns_response == true)

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

let generated_soa_answer_gate_covers_truncated_mname_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      truncated_soa_mname_dns_response == true)

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

let generated_soa_answer_gate_covers_trailing_timers_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      trailing_soa_timers_dns_response == true)

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

let generated_soa_answer_gate_covers_compressed_mname_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      compressed_soa_mname_dns_response == true)

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

let generated_txt_answer_gate_accepts_valid_txt_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      valid_txt_rdata_dns_response == true)

let generated_txt_answer_gate_accepts_empty_string_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      empty_txt_string_rdata_dns_response == true)

let generated_txt_answer_gate_covers_zero_length_rdata_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      zero_length_txt_rdata_dns_response == true)

let generated_txt_answer_gate_covers_truncated_string_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      truncated_txt_string_dns_response == true)

let valid_srv_rdata_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x21uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x21uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x0buy;
    0x00uy; 0x01uy;
    0x00uy; 0x02uy;
    0x01uy; 0xbbuy;
    0x03uy; 0x73uy; 0x76uy; 0x63uy; 0x00uy
  ]

let valid_srv_rdata_parse_packet_test =
  assert_norm (
    match parse_dns_packet_bytes valid_srv_rdata_dns_response with
    | Some p ->
        L.length p.answers == 1 /\
        (match p.answers with
         | rr :: [] ->
             rr.rtype == SRV /\
             rr.rdlen == 11us /\
             FStar.Bytes.length rr.rdata == 11
         | _ -> false)
    | None -> false)

let truncated_srv_fixed_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x21uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x21uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x05uy;
    0x00uy; 0x01uy;
    0x00uy; 0x02uy;
    0x01uy
  ]

let truncated_srv_fixed_parse_packet_test =
  assert_norm (parse_dns_packet_bytes truncated_srv_fixed_dns_response == None)

let truncated_srv_target_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x21uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x21uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x09uy;
    0x00uy; 0x01uy;
    0x00uy; 0x02uy;
    0x01uy; 0xbbuy;
    0x03uy; 0x73uy; 0x76uy
  ]

let truncated_srv_target_parse_packet_test =
  assert_norm (parse_dns_packet_bytes truncated_srv_target_dns_response == None)

let trailing_srv_target_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x21uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x21uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x08uy;
    0x00uy; 0x01uy;
    0x00uy; 0x02uy;
    0x01uy; 0xbbuy;
    0x00uy; 0xffuy
  ]

let trailing_srv_target_parse_packet_test =
  assert_norm (parse_dns_packet_bytes trailing_srv_target_dns_response == None)

let compressed_srv_target_dns_response : list FStar.UInt8.t =
  [
    0x12uy; 0x34uy;
    0x81uy; 0x80uy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy;
    0x00uy; 0x00uy;
    0x00uy;
    0x00uy; 0x21uy;
    0x00uy; 0x01uy;
    0x00uy;
    0x00uy; 0x21uy;
    0x00uy; 0x01uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x08uy;
    0x00uy; 0x01uy;
    0x00uy; 0x02uy;
    0x01uy; 0xbbuy;
    0xc0uy; 0x0cuy
  ]

let compressed_srv_target_parse_packet_test =
  assert_norm (parse_dns_packet_bytes compressed_srv_target_dns_response == None)

let generated_srv_answer_gate_accepts_valid_srv_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      valid_srv_rdata_dns_response == true)

let generated_srv_answer_gate_covers_truncated_fixed_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      truncated_srv_fixed_dns_response == true)

let generated_srv_answer_gate_covers_truncated_target_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      truncated_srv_target_dns_response == true)

let generated_srv_answer_gate_covers_trailing_target_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      trailing_srv_target_dns_response == true)

let generated_srv_answer_gate_covers_compressed_target_test =
  assert_norm (
    generated_uncompressed_question_answer_packet_subset_applicable
      compressed_srv_target_dns_response == true)

let boundary_valid_single_question_dns_query_test =
  assert_norm (parse_dns_packet_bytes_at_boundary valid_single_question_dns_query ==
               parse_dns_packet_bytes valid_single_question_dns_query)

let boundary_valid_single_label_question_dns_query_test =
  assert_norm (parse_dns_packet_bytes_at_boundary valid_single_label_question_dns_query ==
               parse_dns_packet_bytes valid_single_label_question_dns_query)

let boundary_valid_two_label_question_dns_query_test =
  assert_norm (parse_dns_packet_bytes_at_boundary valid_two_label_question_dns_query ==
               parse_dns_packet_bytes valid_two_label_question_dns_query)

let boundary_valid_three_label_question_dns_query_test =
  assert_norm (parse_dns_packet_bytes_at_boundary valid_three_label_question_dns_query ==
               parse_dns_packet_bytes valid_three_label_question_dns_query)

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

let boundary_accepts_compressed_answer_name_test =
  assert_norm (parse_dns_packet_bytes_at_boundary valid_compressed_answer_name_dns_response ==
               parse_dns_packet_bytes valid_compressed_answer_name_dns_response)

let boundary_rejects_self_loop_compressed_answer_name_test =
  assert_norm (parse_dns_packet_bytes_at_boundary self_loop_compressed_answer_name_dns_response ==
               parse_dns_packet_bytes self_loop_compressed_answer_name_dns_response)

let boundary_rejects_out_of_range_compressed_answer_name_test =
  assert_norm (parse_dns_packet_bytes_at_boundary out_of_range_compressed_answer_name_dns_response ==
               parse_dns_packet_bytes out_of_range_compressed_answer_name_dns_response)

let boundary_accepts_aaaa_answer_test =
  assert_norm (parse_dns_packet_bytes_at_boundary valid_aaaa_answer_dns_response ==
               parse_dns_packet_bytes valid_aaaa_answer_dns_response)

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

let boundary_accepts_srv_rdata_test =
  assert_norm (parse_dns_packet_bytes_at_boundary valid_srv_rdata_dns_response ==
               parse_dns_packet_bytes valid_srv_rdata_dns_response)

let boundary_rejects_truncated_srv_fixed_test =
  assert_norm (parse_dns_packet_bytes_at_boundary truncated_srv_fixed_dns_response ==
               parse_dns_packet_bytes truncated_srv_fixed_dns_response)

let boundary_rejects_truncated_srv_target_test =
  assert_norm (parse_dns_packet_bytes_at_boundary truncated_srv_target_dns_response ==
               parse_dns_packet_bytes truncated_srv_target_dns_response)

let boundary_rejects_trailing_srv_target_test =
  assert_norm (parse_dns_packet_bytes_at_boundary trailing_srv_target_dns_response ==
               parse_dns_packet_bytes trailing_srv_target_dns_response)

let boundary_rejects_compressed_srv_target_test =
  assert_norm (parse_dns_packet_bytes_at_boundary compressed_srv_target_dns_response ==
               parse_dns_packet_bytes compressed_srv_target_dns_response)

let boundary_backend_status_test =
  assert_norm (active_parser_backend == EverParseGeneratedSubset /\
               everparse_subset_boundary_available == true /\
               everparse_generated_parser_available == false /\
               everparse_3d_grammar_available_at_boundary == true /\
               everparse_generated_artifact_build_gate_available_at_boundary == true /\
               everparse_generated_artifact_linked_in_adapter_verification_at_boundary == true /\
               everparse_generated_artifact_wired_into_active_parser_at_boundary == true /\
               everparse_generated_subset_gate_active_at_boundary == true /\
               everparse_generated_single_label_question_gate_active_at_boundary == false /\
               everparse_generated_two_label_question_gate_active_at_boundary == false /\
               everparse_generated_uncompressed_question_gate_active_at_boundary == true /\
               everparse_generated_single_answer_rr_gate_active_at_boundary == true /\
               everparse_generated_a_aaaa_answer_rr_gate_active_at_boundary == true /\
               everparse_generated_name_rdata_answer_rr_gate_active_at_boundary == true /\
               everparse_generated_mx_answer_rr_gate_active_at_boundary == true /\
               everparse_generated_soa_answer_rr_gate_active_at_boundary == true /\
               everparse_generated_srv_answer_rr_gate_active_at_boundary == true /\
               everparse_generated_txt_answer_rr_gate_active_at_boundary == true)

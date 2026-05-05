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

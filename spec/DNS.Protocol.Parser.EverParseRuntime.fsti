module DNS.Protocol.Parser.EverParseRuntime

open LowStar.Buffer
open FStar.HyperStack.ST

(* Trusted C adapter for the EverParse-generated DNSProtocolWrapper entry
   points. The C symbols are produced by make everparse-generate and verified
   by make everparse-verify; this interface only exposes the narrow calls
   needed by the active Low* parser boundary. *)

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_header DnsprotocolCheckDnsHeader\n")]
val check_dns_header :
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_root_question DnsprotocolCheckDnsRootQuestion\n")]
val check_dns_root_question :
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_single_label_question DnsprotocolCheckDnsSingleLabelQuestion\n")]
val check_dns_single_label_question :
  label_length:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_two_label_question DnsprotocolCheckDnsTwoLabelQuestion\n")]
val check_dns_two_label_question :
  first_label_length:FStar.UInt32.t ->
  second_label_length:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question DnsprotocolCheckDnsUncompressedQuestion\n")]
val check_dns_uncompressed_question :
  qname_length:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question_answer_packet DnsprotocolCheckDnsUncompressedQuestionAnswerPacket\n")]
val check_dns_uncompressed_question_answer_packet :
  qname_length:FStar.UInt32.t ->
  rr_name_length:FStar.UInt32.t ->
  rdata_length:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question_a_answer_packet DnsprotocolCheckDnsUncompressedQuestionAAnswerPacket\n")]
val check_dns_uncompressed_question_a_answer_packet :
  qname_length:FStar.UInt32.t ->
  rr_name_length:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question_aaaa_answer_packet DnsprotocolCheckDnsUncompressedQuestionAaaaAnswerPacket\n")]
val check_dns_uncompressed_question_aaaa_answer_packet :
  qname_length:FStar.UInt32.t ->
  rr_name_length:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question_name_rdata_answer_packet DnsprotocolCheckDnsUncompressedQuestionNameRdataAnswerPacket\n")]
val check_dns_uncompressed_question_name_rdata_answer_packet :
  qname_length:FStar.UInt32.t ->
  rr_name_length:FStar.UInt32.t ->
  rdata_name_length:FStar.UInt32.t ->
  expected_rtype:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question_compressed_name_rdata_answer_packet DnsprotocolCheckDnsUncompressedQuestionCompressedNameRdataAnswerPacket\n")]
val check_dns_uncompressed_question_compressed_name_rdata_answer_packet :
  qname_length:FStar.UInt32.t ->
  rr_name_length:FStar.UInt32.t ->
  expected_rtype:FStar.UInt32.t ->
  rdata_name_ptr_hi_value:FStar.UInt32.t ->
  rdata_name_ptr_lo_value:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question_mx_answer_packet DnsprotocolCheckDnsUncompressedQuestionMxAnswerPacket\n")]
val check_dns_uncompressed_question_mx_answer_packet :
  qname_length:FStar.UInt32.t ->
  rr_name_length:FStar.UInt32.t ->
  exchange_name_length:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question_compressed_mx_answer_packet DnsprotocolCheckDnsUncompressedQuestionCompressedMxAnswerPacket\n")]
val check_dns_uncompressed_question_compressed_mx_answer_packet :
  qname_length:FStar.UInt32.t ->
  rr_name_length:FStar.UInt32.t ->
  exchange_name_ptr_hi_value:FStar.UInt32.t ->
  exchange_name_ptr_lo_value:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question_soa_answer_packet DnsprotocolCheckDnsUncompressedQuestionSoaAnswerPacket\n")]
val check_dns_uncompressed_question_soa_answer_packet :
  qname_length:FStar.UInt32.t ->
  rr_name_length:FStar.UInt32.t ->
  mname_length:FStar.UInt32.t ->
  rname_length:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question_compressed_soa_mname_answer_packet DnsprotocolCheckDnsUncompressedQuestionCompressedSoaMnameAnswerPacket\n")]
val check_dns_uncompressed_question_compressed_soa_mname_answer_packet :
  qname_length:FStar.UInt32.t ->
  rr_name_length:FStar.UInt32.t ->
  rname_length:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question_compressed_soa_rname_answer_packet DnsprotocolCheckDnsUncompressedQuestionCompressedSoaRnameAnswerPacket\n")]
val check_dns_uncompressed_question_compressed_soa_rname_answer_packet :
  qname_length:FStar.UInt32.t ->
  rr_name_length:FStar.UInt32.t ->
  mname_length:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question_compressed_soa_answer_packet DnsprotocolCheckDnsUncompressedQuestionCompressedSoaAnswerPacket\n")]
val check_dns_uncompressed_question_compressed_soa_answer_packet :
  qname_length:FStar.UInt32.t ->
  rr_name_length:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question_srv_answer_packet DnsprotocolCheckDnsUncompressedQuestionSrvAnswerPacket\n")]
val check_dns_uncompressed_question_srv_answer_packet :
  qname_length:FStar.UInt32.t ->
  rr_name_length:FStar.UInt32.t ->
  target_name_length:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question_compressed_srv_answer_packet DnsprotocolCheckDnsUncompressedQuestionCompressedSrvAnswerPacket\n")]
val check_dns_uncompressed_question_compressed_srv_answer_packet :
  qname_length:FStar.UInt32.t ->
  rr_name_length:FStar.UInt32.t ->
  target_name_ptr_hi_value:FStar.UInt32.t ->
  target_name_ptr_lo_value:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question_txt_answer_packet DnsprotocolCheckDnsUncompressedQuestionTxtAnswerPacket\n")]
val check_dns_uncompressed_question_txt_answer_packet :
  qname_length:FStar.UInt32.t ->
  rr_name_length:FStar.UInt32.t ->
  rdata_length:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question_compressed_answer_name_packet DnsprotocolCheckDnsUncompressedQuestionCompressedAnswerNamePacket\n")]
val check_dns_uncompressed_question_compressed_answer_name_packet :
  qname_length:FStar.UInt32.t ->
  rdata_length:FStar.UInt32.t ->
  rr_name_ptr_hi_value:FStar.UInt32.t ->
  rr_name_ptr_lo_value:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_opt_additional_packet DnsprotocolCheckDnsOptAdditionalPacket\n")]
val check_dns_opt_additional_packet :
  option_payload_length:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

[@ (CPrologue "\
#include \"DNSProtocolWrapper.h\"\n\
#define DNS_Protocol_Parser_EverParseRuntime_check_dns_uncompressed_question_opt_additional_packet DnsprotocolCheckDnsUncompressedQuestionOptAdditionalPacket\n")]
val check_dns_uncompressed_question_opt_additional_packet :
  qname_length:FStar.UInt32.t ->
  option_payload_length:FStar.UInt32.t ->
  base:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 base /\
      FStar.UInt32.v len <= length base))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

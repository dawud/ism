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

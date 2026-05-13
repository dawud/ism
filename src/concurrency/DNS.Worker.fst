module DNS.Worker

open FStar.HyperStack.ST
open LowStar.Buffer
open Steel.Memory
open Steel.ST.Util
open DNS.Protocol
open DNS.RCode
open DNS.QUIC.StreamMapping
open DNS.QUIC.Multiplexer
module PARSE = DNS.Protocol.Parser
module SER = DNS.Protocol.Serializer
module Z = DNS.Zone.RadixTree

val build_worker_response_bytes :
  root:Z.tree_node ->
  request:dns_packet ->
  Tot (option (list FStar.UInt8.t))

let build_worker_response_bytes root request =
  match Z.build_authoritative_response_packet root request with
  | Some response -> SER.serialize_dns_packet_bytes response
  | None -> None

let worker_exact_response_bytes_serialize_test =
  assert_norm (
    match build_worker_response_bytes Z.wildcard_test_root Z.exact_question_request with
    | Some _ -> true
    | None -> false)

let worker_nodata_response_bytes_parse_test =
  assert_norm (
    match build_worker_response_bytes Z.wildcard_test_root Z.nodata_question_request with
    | Some bytes ->
        (match PARSE.parse_dns_packet_bytes bytes with
         | Some p ->
             p.header.flags.qr == true /\
             p.header.flags.rcode == 0us /\
             p.header.qdcount == 1us /\
             p.header.ancount == 0us /\
             p.questions == [Z.nodata_aaaa_question] /\
             p.answers == []
         | None -> false)
    | None -> false)

let worker_nxdomain_response_bytes_parse_test =
  assert_norm (
    match build_worker_response_bytes Z.wildcard_test_root Z.missing_question_request with
    | Some bytes ->
        (match PARSE.parse_dns_packet_bytes bytes with
         | Some p ->
             p.header.flags.qr == true /\
             p.header.flags.rcode == 3us /\
             p.header.qdcount == 1us /\
             p.header.ancount == 0us /\
             p.questions == [Z.missing_a_question] /\
             p.answers == []
         | None -> false)
    | None -> false)

let worker_formerr_response_bytes_parse_test =
  assert_norm (
    match build_worker_response_bytes Z.wildcard_test_root Z.empty_question_request with
    | Some bytes ->
        (match PARSE.parse_dns_packet_bytes bytes with
         | Some p ->
             p.header.flags.qr == true /\
             p.header.flags.rcode == 1us /\
             p.header.qdcount == 0us /\
             p.header.ancount == 0us /\
             p.questions == [] /\
             p.answers == []
         | None -> false)
    | None -> false)

(* The Worker Harness *)
(* This loop represents a thread processing a single QUIC connection *)
val worker_loop : 
  conn:buffer connection_context -> 
  id:FStar.UInt64.t -> 
  ST unit
    (requires (fun h0 ->
      live h0 conn /\
      LowStar.Buffer.length conn >= 1 /\
      (let c = FStar.Seq.index (LowStar.Buffer.as_seq h0 conn) 0 in
       FStar.UInt32.v c.cc_num <= FStar.UInt32.v c.cc_capacity /\
       (if FStar.UInt32.v c.cc_num > 0 then
          active_streams_live h0 c.cc_active c.cc_capacity /\
          loc_disjoint (loc_buffer conn) (loc_buffer c.cc_active)
        else True))))
    (ensures (fun h0 _ h1 -> True))

let worker_loop conn id =
  let stream_opt = find_stream conn id in
  match stream_opt with
  | Some ctx_ptr ->
    let s = LowStar.Buffer.index ctx_ptr 0ul in
    begin
      match s.sc_phase with
      | Processing ->
          (* Response generation is not integrated yet; the verified bootstrap
             worker consumes the ready stream by closing the active entry. *)
          close_stream conn id
      | Done -> ()
      | _ -> ()
    end
  | None -> ()

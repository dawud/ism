module DNS.Worker

open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Modifies
open Steel.Memory
open Steel.ST.Util
open DNS.Protocol
open DNS.RCode
open DNS.QUIC.StreamMapping
open DNS.QUIC.Multiplexer
module EGRESS = DNS.QUIC.MsQuicEgress
module PARSE = DNS.Protocol.Parser
module SER = DNS.Protocol.Serializer
module Z = DNS.Zone.RadixTree
module MINIMAL = DNS.Worker.Minimal
module L = FStar.List.Tot

val build_worker_response_bytes :
  root:Z.tree_node ->
  request:dns_packet ->
  Tot (result:option (list FStar.UInt8.t){
    match result with
    | Some bytes -> exists response. Z.build_authoritative_response_packet root request == Some response /\
        PARSE.parse_dns_packet_bytes bytes == Some response
    | None -> True})

let build_worker_response_bytes root request =
  match Z.build_authoritative_response_packet root request with
  | Some response -> SER.serialize_dns_packet_bytes response
  | None -> None

val build_worker_response_bytes_from_buffer :
  root:Z.tree_node ->
  request_buffer:buffer FStar.UInt8.t ->
  request_len:FStar.UInt32.t ->
  Stack (option (list FStar.UInt8.t))
    (requires (fun h0 ->
      live h0 request_buffer /\
      FStar.UInt32.v request_len <= LowStar.Buffer.length request_buffer))
    (ensures (fun h0 result h1 -> modifies_none h0 h1 /\
      (match result with
       | None -> True
       | Some bytes -> exists request response.
           PARSE.parse_dns_packet_bytes (PARSE.sequence_bytes (as_seq h0 request_buffer) 0
             (FStar.UInt32.v request_len)) == Some request /\
           Z.build_authoritative_response_packet root request == Some response /\
           PARSE.parse_dns_packet_bytes bytes == Some response)))

let build_worker_response_bytes_from_buffer root request_buffer request_len =
  match PARSE.parse_dns_packet_buffer request_buffer request_len with
  | Some request -> build_worker_response_bytes root request
  | None -> None

#push-options "--fuel 8 --ifuel 4"
let worker_exact_response_bytes_serialize_test =
  let rr = Z.exact_record in
  let packet = { Z.exact_question_request with
    header = { Z.exact_question_request.header with
      flags = PARSE.uint16_to_flags 0x8100us; ancount = 1us };
    answers = [rr] } in
  let payload = [127uy;0uy;0uy;1uy] in
  let name = SER.serialize_qname_labels rr.name in
  let qs = L.append name [0uy;1uy;0uy;1uy] in
  let rs = L.append name [0uy;1uy;0uy;1uy;0uy;0uy;0uy;60uy;0uy;4uy;127uy;0uy;0uy;1uy] in
  assert_norm (DNS.Protocol.OPT.bytes_to_list rr.rdata == payload);
  SER.lemma_record_payload_serialization rr payload;
  assert_norm (SER.serialize_resource_record_fields_bytes rr.name A 1us 60ul payload == Some rs);
  assert (SER.serialize_resource_record_bytes rr == Some rs);
  assert_norm (L.append rs [] == rs);
  assert (SER.serialize_resource_records_bytes packet.answers == Some rs);
  assert_norm (SER.serialize_questions_bytes packet.questions == Some qs);
  assert_norm (Z.build_authoritative_response_packet Z.wildcard_test_root
    Z.exact_question_request == Some packet);
  assert_norm (PARSE.parse_dns_packet_bytes (L.append (SER.serialize_header_bytes packet.header)
    (L.append qs rs)) == Some packet);
  SER.lemma_checked_packet_serialization packet qs rs [] [];
  assert (Some? (build_worker_response_bytes Z.wildcard_test_root Z.exact_question_request))
#pop-options

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

val copy_response_bytes_to_buffer :
  bytes:list FStar.UInt8.t ->
  out:buffer FStar.UInt8.t ->
  pos:nat ->
  ST unit
    (requires (fun h0 ->
      live h0 out /\
      pos + L.length bytes <= LowStar.Buffer.length out /\
      pos + L.length bytes <= 4294967295))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer out) h0 h1 /\
      live h1 out))
    (decreases (L.length bytes))

let rec copy_response_bytes_to_buffer bytes out pos =
  match bytes with
  | [] -> ()
  | byte :: rest ->
      assert (pos < LowStar.Buffer.length out);
      assert (pos <= 4294967295);
      let idx = FStar.UInt32.uint_to_t pos in
      assert (FStar.UInt32.v idx == pos);
      LowStar.Buffer.upd out idx byte;
      assert (pos + 1 + L.length rest <= LowStar.Buffer.length out);
      assert (pos + 1 + L.length rest <= 4294967295);
      copy_response_bytes_to_buffer rest out (pos + 1)

val prepare_worker_response_send :
  root:Z.tree_node ->
  ctx_ptr:buffer stream_context ->
  response_buffer:buffer FStar.UInt8.t ->
  response_capacity:FStar.UInt32.t ->
  request_len:FStar.UInt32.t ->
  ST (option EGRESS.msquic_send_descriptor)
    (requires (fun h0 ->
      live h0 ctx_ptr /\
      LowStar.Buffer.length ctx_ptr >= 1 /\
      live h0 response_buffer /\
      FStar.UInt32.v response_capacity <= LowStar.Buffer.length response_buffer /\
      (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
       live h0 ctx.sc_buf /\
       FStar.UInt32.v request_len <= LowStar.Buffer.length ctx.sc_buf)))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer response_buffer) h0 h1 /\
      live h1 response_buffer))

let prepare_worker_response_send root ctx_ptr response_buffer response_capacity request_len =
  let s = LowStar.Buffer.index ctx_ptr 0ul in
  match build_worker_response_bytes_from_buffer root s.sc_buf request_len with
  | Some response_bytes ->
      if L.length response_bytes <= FStar.UInt32.v response_capacity then
        begin
          let response_len = FStar.UInt32.uint_to_t (L.length response_bytes) in
          assert (FStar.UInt32.v response_len == L.length response_bytes);
          let response = {
            EGRESS.msrf_stream_id = s.sc_id;
            EGRESS.msrf_data = response_buffer;
            EGRESS.msrf_len = response_len;
            EGRESS.msrf_fin = true;
          } in
          let descriptor = EGRESS.prepare_response_send () ctx_ptr response in
          copy_response_bytes_to_buffer response_bytes response_buffer 0;
          Some descriptor
        end
      else
        None
  | None -> None

val prepare_worker_minimal_error_response_send :
  ctx_ptr:buffer stream_context ->
  response_buffer:buffer FStar.UInt8.t ->
  response_capacity:FStar.UInt32.t ->
  request_len:FStar.UInt32.t ->
  ST FStar.UInt32.t
    (requires (fun h0 ->
      live h0 ctx_ptr /\
      LowStar.Buffer.length ctx_ptr >= 1 /\
      live h0 response_buffer /\
      FStar.UInt32.v response_capacity <= LowStar.Buffer.length response_buffer /\
      (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
       live h0 ctx.sc_buf /\
       FStar.UInt32.v request_len <= LowStar.Buffer.length ctx.sc_buf)))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer response_buffer) h0 h1 /\
      live h1 response_buffer))

let prepare_worker_minimal_error_response_send ctx_ptr response_buffer response_capacity request_len =
  MINIMAL.prepare_worker_minimal_error_response_send
    ctx_ptr
    response_buffer
    response_capacity
    request_len

(* The Worker Harness *)
(* This loop represents a thread processing a single QUIC connection *)
val worker_loop_with_root :
  root:Z.tree_node ->
  conn:buffer connection_context -> 
  response_buffer:buffer FStar.UInt8.t ->
  response_capacity:FStar.UInt32.t ->
  id:FStar.UInt64.t -> 
  ST unit
    (requires (fun h0 ->
      live h0 conn /\
      LowStar.Buffer.length conn >= 1 /\
      live h0 response_buffer /\
      FStar.UInt32.v response_capacity <= LowStar.Buffer.length response_buffer /\
      loc_disjoint (loc_buffer conn) (loc_buffer response_buffer) /\
      (let c = FStar.Seq.index (LowStar.Buffer.as_seq h0 conn) 0 in
       FStar.UInt32.v c.cc_num <= FStar.UInt32.v c.cc_capacity /\
       (if FStar.UInt32.v c.cc_num > 0 then
          active_streams_live h0 c.cc_active c.cc_capacity /\
          loc_disjoint (loc_buffer conn) (loc_buffer c.cc_active)
        else True))))
    (ensures (fun h0 _ h1 -> True))

let worker_loop_with_root root conn response_buffer response_capacity id =
  let stream_opt = find_stream conn id in
  match stream_opt with
  | Some ctx_ptr ->
    let s = LowStar.Buffer.index ctx_ptr 0ul in
    begin
      match s.sc_phase with
      | Processing request_len ->
          let _send_descriptor =
            prepare_worker_response_send root ctx_ptr response_buffer response_capacity request_len in
          ()
      | Done -> ()
      | _ -> ()
    end
  | None -> ()

val worker_loop :
  conn:buffer connection_context ->
  response_buffer:buffer FStar.UInt8.t ->
  response_capacity:FStar.UInt32.t ->
  id:FStar.UInt64.t ->
  ST unit
    (requires (fun h0 ->
      live h0 conn /\
      LowStar.Buffer.length conn >= 1 /\
      live h0 response_buffer /\
      FStar.UInt32.v response_capacity <= LowStar.Buffer.length response_buffer /\
      loc_disjoint (loc_buffer conn) (loc_buffer response_buffer) /\
      (let c = FStar.Seq.index (LowStar.Buffer.as_seq h0 conn) 0 in
       FStar.UInt32.v c.cc_num <= FStar.UInt32.v c.cc_capacity /\
       (if FStar.UInt32.v c.cc_num > 0 then
          active_streams_live h0 c.cc_active c.cc_capacity /\
          loc_disjoint (loc_buffer conn) (loc_buffer c.cc_active)
        else True))))
    (ensures (fun h0 _ h1 -> True))

let worker_loop conn response_buffer response_capacity id =
  worker_loop_with_root Z.wildcard_test_root conn response_buffer response_capacity id

module DNS.ShellResponseBoundary

open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Modifies
module COMPLETE = DNS.QUIC.MsQuicSendCompletion
module EGRESS = DNS.QUIC.MsQuicEgress
module MUX = DNS.QUIC.Multiplexer
module STREAM = DNS.QUIC.StreamMapping

(* C-facing response boundary for the unverified shell. The shell provides a
   response buffer already filled by verified response construction and receives
   the immutable length to hand to MsQuic. Full worker response construction
   still stays behind the verification-only worker path until its list-backed
   packet model is rewritten for Low*. *)
val prepare_response_send_for_stream :
  ctx_ptr:buffer STREAM.stream_context ->
  response_buffer:buffer FStar.UInt8.t ->
  response_len:FStar.UInt32.t ->
  fin_code:FStar.UInt8.t ->
  ST FStar.UInt32.t
    (requires (fun h0 ->
      live h0 ctx_ptr /\
      LowStar.Buffer.length ctx_ptr >= 1 /\
      live h0 response_buffer /\
      FStar.UInt32.v response_len <= LowStar.Buffer.length response_buffer /\
      (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
       live h0 ctx.STREAM.sc_buf)))
    (ensures (fun h0 _ h1 ->
      modifies_none h0 h1))

let prepare_response_send_for_stream ctx_ptr response_buffer response_len fin_code =
  let s = LowStar.Buffer.index ctx_ptr 0ul in
  let response = {
    EGRESS.msrf_stream_id = s.STREAM.sc_id;
    EGRESS.msrf_data = response_buffer;
    EGRESS.msrf_len = response_len;
    EGRESS.msrf_fin = not (FStar.UInt8.eq fin_code 0uy);
  } in
  let descriptor = EGRESS.prepare_response_send () ctx_ptr response in
  descriptor.EGRESS.mssd_len

val send_outcome_of_code :
  code:FStar.UInt8.t ->
  Tot COMPLETE.msquic_send_outcome

let send_outcome_of_code code =
  if FStar.UInt8.eq code 0uy then
    COMPLETE.SendCompleted
  else
    COMPLETE.SendDropped

(* The shell calls this after MsQuic completes or drops a send prepared through
   the response boundary. The verified side closes the matching stream slot. *)
val complete_response_send_for_stream :
  conn:buffer MUX.connection_context ->
  response_buffer:buffer FStar.UInt8.t ->
  response_len:FStar.UInt32.t ->
  stream_id:FStar.UInt64.t ->
  outcome_code:FStar.UInt8.t ->
  ST FStar.UInt8.t
    (requires (fun h0 ->
      live h0 conn /\
      LowStar.Buffer.length conn >= 1 /\
      live h0 response_buffer /\
      FStar.UInt32.v response_len <= LowStar.Buffer.length response_buffer /\
      (let c = FStar.Seq.index (LowStar.Buffer.as_seq h0 conn) 0 in
       FStar.UInt32.v c.MUX.cc_num <= FStar.UInt32.v c.MUX.cc_capacity /\
       (FStar.UInt32.v c.MUX.cc_num > 0 ==>
        MUX.active_streams_live h0 c.MUX.cc_active c.MUX.cc_capacity /\
        loc_disjoint (loc_buffer conn) (loc_buffer c.MUX.cc_active)))))
    (ensures (fun _h0 _ _h1 -> True))

let complete_response_send_for_stream conn response_buffer response_len stream_id outcome_code =
  let descriptor = {
    EGRESS.mssd_stream_id = stream_id;
    EGRESS.mssd_data = response_buffer;
    EGRESS.mssd_len = response_len;
    EGRESS.mssd_fin = true;
  } in
  let outcome = send_outcome_of_code outcome_code in
  COMPLETE.complete_response_send () conn descriptor outcome;
  1uy

module DNS.QUIC.MsQuicEgress

open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Modifies
open FStar.UInt32
open FStar.UInt64
open DNS.QUIC.StreamMapping

(* Trusted shell token: MsQuic owns encryption, packetization, flow control, and
   the actual stream send. The verified core only prepares immutable bytes for
   that shell send. *)
type msquic_send_borrow = unit

noeq
type response_stream_fragment = {
  msrf_stream_id: FStar.UInt64.t;
  msrf_data: buffer FStar.UInt8.t;
  msrf_len: FStar.UInt32.t;
  msrf_fin: bool;
}

noeq
type msquic_send_descriptor = {
  mssd_stream_id: FStar.UInt64.t;
  mssd_data: buffer FStar.UInt8.t;
  mssd_len: FStar.UInt32.t;
  mssd_fin: bool;
}

val response_stream_fragment_live :
  h:FStar.Monotonic.HyperStack.mem ->
  ctx_ptr:buffer stream_context ->
  response:response_stream_fragment ->
  Type0

let response_stream_fragment_live h ctx_ptr response =
  live h ctx_ptr /\
  LowStar.Buffer.length ctx_ptr >= 1 /\
  live h response.msrf_data /\
  FStar.UInt32.v response.msrf_len <= LowStar.Buffer.length response.msrf_data /\
  (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h ctx_ptr) 0 in
   ctx.sc_id = response.msrf_stream_id /\
   live h ctx.sc_buf)

(* MsQuic-facing egress boundary. The descriptor is a read-only handoff to the
   shell; the shell must keep the response buffer immutable until send
   completion or copy it into shell-owned storage. *)
val prepare_response_send :
  borrow:msquic_send_borrow ->
  ctx_ptr:buffer stream_context ->
  response:response_stream_fragment ->
  Stack msquic_send_descriptor
    (requires (fun h0 ->
      response_stream_fragment_live h0 ctx_ptr response))
    (ensures (fun h0 r h1 ->
      modifies_none h0 h1 /\
      r.mssd_stream_id = response.msrf_stream_id /\
      r.mssd_len = response.msrf_len /\
      r.mssd_fin = response.msrf_fin))

let prepare_response_send _borrow _ctx_ptr response =
  {
    mssd_stream_id = response.msrf_stream_id;
    mssd_data = response.msrf_data;
    mssd_len = response.msrf_len;
    mssd_fin = response.msrf_fin;
  }

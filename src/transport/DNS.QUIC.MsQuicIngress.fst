module DNS.QUIC.MsQuicIngress

open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Modifies
open FStar.UInt32
open FStar.UInt64
open DNS.QUIC.StreamMapping

(* Trusted shell token: the MsQuic callback delivered these bytes after QUIC/TLS
   authentication, transport policy, and stream ownership checks. *)
type msquic_authenticated = unit
type msquic_stream_borrow = unit

noeq
type authenticated_stream_fragment = {
  msif_stream_id: FStar.UInt64.t;
  msif_data: buffer FStar.UInt8.t;
  msif_len: FStar.UInt32.t;
  msif_fin: bool;
}

val authenticated_stream_fragment_live :
  h:FStar.Monotonic.HyperStack.mem ->
  ctx_ptr:buffer stream_context ->
  fragment:authenticated_stream_fragment ->
  Type0

let authenticated_stream_fragment_live h ctx_ptr fragment =
  live h ctx_ptr /\
  LowStar.Buffer.length ctx_ptr >= 1 /\
  live h fragment.msif_data /\
  FStar.UInt32.v fragment.msif_len <= LowStar.Buffer.length fragment.msif_data /\
  (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h ctx_ptr) 0 in
   ctx.sc_id = fragment.msif_stream_id /\
   live h ctx.sc_buf /\
   LowStar.Buffer.length ctx.sc_buf >= 65535 /\
   disjoint fragment.msif_data ctx.sc_buf /\
   loc_disjoint (loc_buffer ctx_ptr) (loc_buffer ctx.sc_buf))

(* MsQuic-facing ingress boundary. The shell owns TLS, QUIC transport, stream
   callbacks, and lifetime checks; the verified core owns DoQ length framing. *)
val handle_authenticated_stream_fragment :
  auth:msquic_authenticated ->
  borrow:msquic_stream_borrow ->
  ctx_ptr:buffer stream_context ->
  fragment:authenticated_stream_fragment ->
  ST stream_phase
    (requires (fun h0 ->
      authenticated_stream_fragment_live h0 ctx_ptr fragment))
    (ensures (fun h0 _ h1 ->
      (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
       modifies (loc_union (loc_buffer ctx_ptr) (loc_buffer ctx.sc_buf)) h0 h1) /\
      live h1 ctx_ptr))

let handle_authenticated_stream_fragment _auth _borrow ctx_ptr fragment =
  handle_stream_data ctx_ptr fragment.msif_data fragment.msif_len

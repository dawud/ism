module DNS.QUIC.MsQuicSendCompletion

open FStar.HyperStack.ST
open LowStar.Buffer
open DNS.QUIC.Multiplexer
module EGRESS = DNS.QUIC.MsQuicEgress

(* Trusted shell token: MsQuic has either completed the send or the shell has
   chosen to drop it, so the verified scheduler may close the stream and the
   shell may decide when to reuse the response buffer. *)
type msquic_send_completion_borrow = unit

type msquic_send_outcome =
  | SendCompleted
  | SendDropped

val send_descriptor_live :
  h:FStar.Monotonic.HyperStack.mem ->
  descriptor:EGRESS.msquic_send_descriptor ->
  Type0

let send_descriptor_live h descriptor =
  live h descriptor.EGRESS.mssd_data /\
  FStar.UInt32.v descriptor.EGRESS.mssd_len <=
    LowStar.Buffer.length descriptor.EGRESS.mssd_data

val complete_response_send :
  borrow:msquic_send_completion_borrow ->
  conn:buffer connection_context ->
  descriptor:EGRESS.msquic_send_descriptor ->
  outcome:msquic_send_outcome ->
  ST unit
    (requires (fun h0 ->
      send_descriptor_live h0 descriptor /\
      live h0 conn /\
      LowStar.Buffer.length conn >= 1 /\
      (let c = FStar.Seq.index (LowStar.Buffer.as_seq h0 conn) 0 in
       FStar.UInt32.v c.cc_num <= FStar.UInt32.v c.cc_capacity /\
       (FStar.UInt32.v c.cc_num > 0 ==>
        active_streams_live h0 c.cc_active c.cc_capacity /\
        loc_disjoint (loc_buffer conn) (loc_buffer c.cc_active)))))
    (ensures (fun h0 _ h1 -> True))

let complete_response_send _borrow conn descriptor _outcome =
  close_stream conn descriptor.EGRESS.mssd_stream_id

module DNS.ShellResponseBoundary

open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Modifies
module COMPLETE = DNS.QUIC.MsQuicSendCompletion
module EGRESS = DNS.QUIC.MsQuicEgress
module MUX = DNS.QUIC.Multiplexer
module STREAM = DNS.QUIC.StreamMapping
module CAST = FStar.Int.Cast

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

val copy_response_bytes_with_prefix :
  response_buffer:buffer FStar.UInt8.t ->
  stream_buffer:buffer FStar.UInt8.t ->
  response_len:FStar.UInt32.t ->
  idx:FStar.UInt32.t{FStar.UInt32.v idx <= FStar.UInt32.v response_len} ->
  ST unit
    (requires (fun h0 ->
      live h0 response_buffer /\
      live h0 stream_buffer /\
      FStar.UInt32.v response_len <= 65535 /\
      FStar.UInt32.v response_len <= LowStar.Buffer.length response_buffer /\
      FStar.UInt32.v response_len + 2 <= LowStar.Buffer.length stream_buffer))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer stream_buffer) h0 h1 /\
      live h1 stream_buffer))
    (decreases (FStar.UInt32.v response_len - FStar.UInt32.v idx))

let rec copy_response_bytes_with_prefix response_buffer stream_buffer response_len idx =
  if FStar.UInt32.eq idx response_len then
    ()
  else
    begin
      assert (FStar.UInt32.v idx < FStar.UInt32.v response_len);
      assert (FStar.UInt32.v idx < 65535);
      assert (2 + FStar.UInt32.v idx < 4294967296);
      let dst_idx = FStar.UInt32.add 2ul idx in
      assert (FStar.UInt32.v idx < LowStar.Buffer.length response_buffer);
      assert (FStar.UInt32.v dst_idx < LowStar.Buffer.length stream_buffer);
      let byte = LowStar.Buffer.index response_buffer idx in
      LowStar.Buffer.upd stream_buffer dst_idx byte;
      assert (FStar.UInt32.v idx + 1 <= FStar.UInt32.v response_len);
      assert (FStar.UInt32.v idx + 1 < 4294967296);
      let next_idx = FStar.UInt32.add idx 1ul in
      assert (FStar.UInt32.v next_idx = FStar.UInt32.v idx + 1);
      copy_response_bytes_with_prefix response_buffer stream_buffer response_len next_idx
    end

val prepare_doq_response_send_for_stream :
  ctx_ptr:buffer STREAM.stream_context ->
  response_buffer:buffer FStar.UInt8.t ->
  response_len:FStar.UInt32.t ->
  stream_buffer:buffer FStar.UInt8.t ->
  stream_capacity:FStar.UInt32.t ->
  fin_code:FStar.UInt8.t ->
  ST FStar.UInt32.t
    (requires (fun h0 ->
      live h0 ctx_ptr /\
      LowStar.Buffer.length ctx_ptr >= 1 /\
      live h0 response_buffer /\
      live h0 stream_buffer /\
      FStar.UInt32.v response_len <= LowStar.Buffer.length response_buffer /\
      FStar.UInt32.v stream_capacity <= LowStar.Buffer.length stream_buffer /\
      loc_disjoint (loc_buffer ctx_ptr) (loc_buffer stream_buffer) /\
      loc_disjoint (loc_buffer response_buffer) (loc_buffer stream_buffer) /\
      (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
       live h0 ctx.STREAM.sc_buf)))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer stream_buffer) h0 h1 /\
      live h1 stream_buffer))

let prepare_doq_response_send_for_stream
  ctx_ptr
  response_buffer
  response_len
  stream_buffer
  stream_capacity
  fin_code =
  if FStar.UInt32.gt response_len 65535ul then
    0ul
  else
    begin
      assert (FStar.UInt32.v response_len <= 65535);
      assert (FStar.UInt32.v response_len + 2 < 4294967296);
      let framed_len = FStar.UInt32.add response_len 2ul in
      if FStar.UInt32.lt stream_capacity framed_len then
        0ul
      else
        begin
          assert (FStar.UInt32.v framed_len <= FStar.UInt32.v stream_capacity);
          assert (FStar.UInt32.v framed_len <= LowStar.Buffer.length stream_buffer);
          assert (2 <= LowStar.Buffer.length stream_buffer);
          assert (0 < LowStar.Buffer.length stream_buffer);
          assert (1 < LowStar.Buffer.length stream_buffer);
          let s = LowStar.Buffer.index ctx_ptr 0ul in
          let hi32 = FStar.UInt32.shift_right response_len 8ul in
          let len_hi = CAST.uint32_to_uint8 hi32 in
          let len_lo = CAST.uint32_to_uint8 response_len in
          LowStar.Buffer.upd stream_buffer 0ul len_hi;
          LowStar.Buffer.upd stream_buffer 1ul len_lo;
          copy_response_bytes_with_prefix response_buffer stream_buffer response_len 0ul;
          let response = {
            EGRESS.msrf_stream_id = s.STREAM.sc_id;
            EGRESS.msrf_data = stream_buffer;
            EGRESS.msrf_len = framed_len;
            EGRESS.msrf_fin = not (FStar.UInt8.eq fin_code 0uy);
          } in
          let descriptor = EGRESS.prepare_response_send () ctx_ptr response in
          descriptor.EGRESS.mssd_len
        end
    end

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

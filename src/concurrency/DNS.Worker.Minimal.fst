module DNS.Worker.Minimal

open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Modifies
open Steel.Memory
open Steel.ST.Util
open DNS.QUIC.StreamMapping

let noerror_response_flags_hi (request_flags_hi:FStar.UInt8.t) : FStar.UInt8.t =
  FStar.UInt8.logor 0x80uy (FStar.UInt8.logand request_flags_hi 0x79uy)

let noerror_response_flags_lo (request_flags_lo:FStar.UInt8.t) : FStar.UInt8.t =
  FStar.UInt8.logand request_flags_lo 0x10uy

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

let prepare_worker_minimal_error_response_send
  ctx_ptr
  response_buffer
  response_capacity
  request_len =
  let s = LowStar.Buffer.index ctx_ptr 0ul in
  if FStar.UInt32.lt request_len 12ul ||
     FStar.UInt32.lt response_capacity 12ul then
    0ul
  else
    begin
      assert (FStar.UInt32.v request_len <= LowStar.Buffer.length s.sc_buf);
      assert (12 <= LowStar.Buffer.length response_buffer);
      assert (1 < LowStar.Buffer.length s.sc_buf);
      assert (0 < LowStar.Buffer.length response_buffer);
      assert (1 < LowStar.Buffer.length response_buffer);
      assert (2 < LowStar.Buffer.length response_buffer);
      assert (3 < LowStar.Buffer.length response_buffer);
      assert (4 < LowStar.Buffer.length response_buffer);
      assert (5 < LowStar.Buffer.length response_buffer);
      assert (6 < LowStar.Buffer.length response_buffer);
      assert (7 < LowStar.Buffer.length response_buffer);
      assert (8 < LowStar.Buffer.length response_buffer);
      assert (9 < LowStar.Buffer.length response_buffer);
      assert (10 < LowStar.Buffer.length response_buffer);
      assert (11 < LowStar.Buffer.length response_buffer);
      let id_hi = LowStar.Buffer.index s.sc_buf 0ul in
      let id_lo = LowStar.Buffer.index s.sc_buf 1ul in
      LowStar.Buffer.upd response_buffer 0ul id_hi;
      LowStar.Buffer.upd response_buffer 1ul id_lo;
      LowStar.Buffer.upd response_buffer 2ul 0x81uy;
      LowStar.Buffer.upd response_buffer 3ul 0x03uy;
      LowStar.Buffer.upd response_buffer 4ul 0x00uy;
      LowStar.Buffer.upd response_buffer 5ul 0x00uy;
      LowStar.Buffer.upd response_buffer 6ul 0x00uy;
      LowStar.Buffer.upd response_buffer 7ul 0x00uy;
      LowStar.Buffer.upd response_buffer 8ul 0x00uy;
      LowStar.Buffer.upd response_buffer 9ul 0x00uy;
      LowStar.Buffer.upd response_buffer 10ul 0x00uy;
      LowStar.Buffer.upd response_buffer 11ul 0x00uy;
      12ul
    end

val prepare_worker_empty_noerror_response_send :
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

let prepare_worker_empty_noerror_response_send
  ctx_ptr
  response_buffer
  response_capacity
  request_len =
  let s = LowStar.Buffer.index ctx_ptr 0ul in
  if FStar.UInt32.lt request_len 12ul ||
     FStar.UInt32.lt response_capacity 12ul then
    0ul
  else
    begin
      assert (FStar.UInt32.v request_len <= LowStar.Buffer.length s.sc_buf);
      assert (12 <= LowStar.Buffer.length response_buffer);
      assert (3 < LowStar.Buffer.length s.sc_buf);
      assert (0 < LowStar.Buffer.length response_buffer);
      assert (1 < LowStar.Buffer.length response_buffer);
      assert (2 < LowStar.Buffer.length response_buffer);
      assert (3 < LowStar.Buffer.length response_buffer);
      assert (4 < LowStar.Buffer.length response_buffer);
      assert (5 < LowStar.Buffer.length response_buffer);
      assert (6 < LowStar.Buffer.length response_buffer);
      assert (7 < LowStar.Buffer.length response_buffer);
      assert (8 < LowStar.Buffer.length response_buffer);
      assert (9 < LowStar.Buffer.length response_buffer);
      assert (10 < LowStar.Buffer.length response_buffer);
      assert (11 < LowStar.Buffer.length response_buffer);
      let id_hi = LowStar.Buffer.index s.sc_buf 0ul in
      let id_lo = LowStar.Buffer.index s.sc_buf 1ul in
      let request_flags_hi = LowStar.Buffer.index s.sc_buf 2ul in
      let request_flags_lo = LowStar.Buffer.index s.sc_buf 3ul in
      LowStar.Buffer.upd response_buffer 0ul id_hi;
      LowStar.Buffer.upd response_buffer 1ul id_lo;
      LowStar.Buffer.upd response_buffer 2ul (noerror_response_flags_hi request_flags_hi);
      LowStar.Buffer.upd response_buffer 3ul (noerror_response_flags_lo request_flags_lo);
      LowStar.Buffer.upd response_buffer 4ul 0x00uy;
      LowStar.Buffer.upd response_buffer 5ul 0x00uy;
      LowStar.Buffer.upd response_buffer 6ul 0x00uy;
      LowStar.Buffer.upd response_buffer 7ul 0x00uy;
      LowStar.Buffer.upd response_buffer 8ul 0x00uy;
      LowStar.Buffer.upd response_buffer 9ul 0x00uy;
      LowStar.Buffer.upd response_buffer 10ul 0x00uy;
      LowStar.Buffer.upd response_buffer 11ul 0x00uy;
      12ul
    end

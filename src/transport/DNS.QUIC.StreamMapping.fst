module DNS.QUIC.StreamMapping

open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Modifies
open Steel.Memory
open Steel.ST.Util
open FStar.UInt16
open FStar.UInt32
open FStar.UInt64

(* The state machine for a single QUIC stream *)
type stream_phase =
  | ReadingLength
  | ReadingLengthHigh of (hi:FStar.UInt8.t)
  | ReadingMessage of (expected: FStar.UInt16.t * current: FStar.UInt32.t)
  | Processing of (expected:FStar.UInt16.t)
  | Done

(* The Stream Context held in shared memory but protected by Steel permissions *)
noeq
type stream_context = {
  sc_id:    FStar.UInt64.t;
  sc_phase: stream_phase;
  sc_buf:   buffer FStar.UInt8.t;
}

(* --- Stream Multiplexing Logic --- *)

val u16_from_be_bytes : hi:FStar.UInt8.t -> lo:FStar.UInt8.t -> Tot FStar.UInt16.t
let u16_from_be_bytes hi lo =
  let hi16 = FStar.UInt16.uint_to_t (FStar.UInt8.v hi) in
  let lo16 = FStar.UInt16.uint_to_t (FStar.UInt8.v lo) in
  assert (FStar.UInt16.v hi16 < 256);
  assert (FStar.UInt16.v lo16 < 256);
  let shifted = FStar.UInt16.shift_left hi16 8ul in
  assert (FStar.UInt16.v shifted <= 65280);
  assert (FStar.UInt16.v shifted + FStar.UInt16.v lo16 <= 65535);
  FStar.UInt16.add shifted lo16

val parse_u16_from_fragment :
    data:buffer FStar.UInt8.t ->
    Stack FStar.UInt16.t
      (requires (fun h0 ->
        live h0 data /\
        LowStar.Buffer.length data >= 2))
      (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let parse_u16_from_fragment data =
  let hi = LowStar.Buffer.index data 0ul in
  let lo = LowStar.Buffer.index data 1ul in
  u16_from_be_bytes hi lo

val body_bytes_after_prefix : len:FStar.UInt32.t -> Tot FStar.UInt32.t
let body_bytes_after_prefix len =
  if FStar.UInt32.gte len 2ul then
    FStar.UInt32.sub len 2ul
  else
    0ul

val body_bytes_after_stored_prefix : len:FStar.UInt32.t -> Tot FStar.UInt32.t
let body_bytes_after_stored_prefix len =
  if FStar.UInt32.gte len 1ul then
    FStar.UInt32.sub len 1ul
  else
    0ul

val u16_to_u32 : n:FStar.UInt16.t -> Tot FStar.UInt32.t
let u16_to_u32 n =
  FStar.UInt32.uint_to_t (FStar.UInt16.v n)

val advance_message :
    expected:FStar.UInt16.t ->
    current:FStar.UInt32.t ->
    incoming:FStar.UInt32.t{
      FStar.UInt32.v current + FStar.UInt32.v incoming < 4294967296} ->
    Tot stream_phase

let advance_message expected current incoming =
  assert (FStar.UInt32.v current + FStar.UInt32.v incoming < 4294967296);
  let total_len = FStar.UInt32.add current incoming in
  let expected32 = u16_to_u32 expected in
  if FStar.UInt32.gte total_len expected32 then
    Processing expected
  else
    begin
      assert (FStar.UInt32.v total_len < FStar.UInt16.v expected);
      ReadingMessage (expected, total_len)
    end

val remaining_message : expected:FStar.UInt16.t -> current:FStar.UInt32.t -> Tot FStar.UInt32.t
let remaining_message expected current =
  let expected32 = u16_to_u32 expected in
  if FStar.UInt32.gte current expected32 then
    0ul
  else
    begin
      assert (FStar.UInt32.v expected32 - FStar.UInt32.v current < 4294967296);
      FStar.UInt32.sub expected32 current
    end

val advance_message_checked :
    expected:FStar.UInt16.t ->
    current:FStar.UInt32.t ->
    incoming:FStar.UInt32.t ->
    Tot stream_phase

let advance_message_checked expected current incoming =
  let remaining = remaining_message expected current in
  if FStar.UInt32.gt incoming remaining then
    Done
  else
    begin
      assert (FStar.UInt32.v incoming <= FStar.UInt32.v remaining);
      assert (FStar.UInt32.v current + FStar.UInt32.v incoming < 4294967296);
    advance_message expected current incoming
    end

val bounded_copy_len : available:FStar.UInt32.t -> wanted:FStar.UInt32.t -> Tot FStar.UInt32.t
let bounded_copy_len available wanted =
  if FStar.UInt32.lt available wanted then available else wanted

val next_stream_phase :
    ctx:stream_context ->
    data:buffer FStar.UInt8.t ->
    len:FStar.UInt32.t ->
    Stack stream_phase
      (requires (fun h0 ->
        live h0 data /\
        FStar.UInt32.v len <= LowStar.Buffer.length data))
      (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let next_stream_phase ctx data len =
  match ctx.sc_phase with
  | ReadingLengthHigh hi ->
      if FStar.UInt32.gte len 1ul then
        begin
          assert (LowStar.Buffer.length data >= 1);
          let lo = LowStar.Buffer.index data 0ul in
          let expected = u16_from_be_bytes hi lo in
          let body_len = body_bytes_after_stored_prefix len in
          advance_message_checked expected 0ul body_len
        end
      else
        ctx.sc_phase
  | ReadingLength ->
      if FStar.UInt32.gte len 2ul then
        begin
          assert (LowStar.Buffer.length data >= 2);
          let expected = parse_u16_from_fragment data in
          let body_len = body_bytes_after_prefix len in
          advance_message_checked expected 0ul body_len
        end
      else if FStar.UInt32.eq len 1ul then
        begin
          assert (LowStar.Buffer.length data >= 1);
          let hi = LowStar.Buffer.index data 0ul in
          ReadingLengthHigh hi
        end
      else
        ctx.sc_phase
  | ReadingMessage (expected, current) ->
      advance_message_checked expected current len
  | _ -> ctx.sc_phase

val copy_body_bytes :
    ctx:stream_context ->
    data:buffer FStar.UInt8.t ->
    len:FStar.UInt32.t ->
    ST unit
      (requires (fun h0 ->
        live h0 ctx.sc_buf /\
        LowStar.Buffer.length ctx.sc_buf >= 65535 /\
        live h0 data /\
        disjoint data ctx.sc_buf /\
        FStar.UInt32.v len <= LowStar.Buffer.length data))
      (ensures (fun h0 _ h1 ->
        modifies (loc_buffer ctx.sc_buf) h0 h1 /\
        live h1 ctx.sc_buf))

let copy_body_bytes ctx data len =
  match ctx.sc_phase with
  | ReadingLengthHigh hi ->
      if FStar.UInt32.gte len 1ul then
        begin
          assert (LowStar.Buffer.length data >= 1);
          let lo = LowStar.Buffer.index data 0ul in
          let expected = u16_from_be_bytes hi lo in
          let available = body_bytes_after_stored_prefix len in
          let wanted = remaining_message expected 0ul in
          let count = bounded_copy_len available wanted in
          if FStar.UInt32.gt count 0ul then
            begin
              assert (FStar.UInt32.v count <= FStar.UInt32.v available);
              assert (FStar.UInt32.v count <= FStar.UInt16.v expected);
              LowStar.Buffer.blit data 1ul ctx.sc_buf 0ul count
            end
          else
            ()
        end
      else
        ()
  | ReadingLength ->
      if FStar.UInt32.gte len 2ul then
        begin
          assert (LowStar.Buffer.length data >= 2);
          let expected = parse_u16_from_fragment data in
          let available = body_bytes_after_prefix len in
          let wanted = remaining_message expected 0ul in
          let count = bounded_copy_len available wanted in
          if FStar.UInt32.gt count 0ul then
            begin
              assert (FStar.UInt32.v count <= FStar.UInt32.v available);
              assert (FStar.UInt32.v count <= FStar.UInt16.v expected);
              LowStar.Buffer.blit data 2ul ctx.sc_buf 0ul count
            end
          else
            ()
        end
      else
        ()
  | ReadingMessage (expected, current) ->
      if FStar.UInt32.lt current (u16_to_u32 expected) then
        begin
          let wanted = remaining_message expected current in
          let count = bounded_copy_len len wanted in
          if FStar.UInt32.gt count 0ul then
            begin
              assert (FStar.UInt32.v count <= FStar.UInt32.v len);
              assert (FStar.UInt32.v count <= FStar.UInt16.v expected - FStar.UInt32.v current);
              assert (FStar.UInt32.v current + FStar.UInt32.v count <= FStar.UInt16.v expected);
              LowStar.Buffer.blit data 0ul ctx.sc_buf current count
            end
          else
            ()
        end
      else
        ()
  | _ -> ()

(* Stateful accumulation of QUIC frames into DNS messages *)
val handle_stream_data :
    ctx_ptr:buffer stream_context ->
    data:buffer FStar.UInt8.t ->
    len:FStar.UInt32.t ->
    ST stream_phase
      (requires (fun h0 ->
        live h0 ctx_ptr /\
        LowStar.Buffer.length ctx_ptr >= 1 /\
        live h0 data /\
        FStar.UInt32.v len <= LowStar.Buffer.length data /\
        (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
         live h0 ctx.sc_buf /\
         LowStar.Buffer.length ctx.sc_buf >= 65535 /\
         disjoint data ctx.sc_buf /\
         loc_disjoint (loc_buffer ctx_ptr) (loc_buffer ctx.sc_buf))))
      (ensures (fun h0 _ h1 ->
        (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
         modifies (loc_union (loc_buffer ctx_ptr) (loc_buffer ctx.sc_buf)) h0 h1) /\
        live h1 ctx_ptr))

let handle_stream_data ctx_ptr data len =
  let ctx = LowStar.Buffer.index ctx_ptr 0ul in
  let phase = next_stream_phase ctx data len in
  copy_body_bytes ctx data len;
  let next_ctx = { ctx with sc_phase = phase } in
  LowStar.Buffer.upd ctx_ptr 0ul next_ctx;
  phase

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
  | ReadingLength  of (acc: FStar.UInt32.t)
  | ReadingMessage of (expected: FStar.UInt16.t * current: FStar.UInt32.t)
  | Processing
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
  FStar.UInt16.uint_to_t (Prims.op_Addition (Prims.op_Multiply (FStar.UInt8.v hi) 256) (FStar.UInt8.v lo))

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
  if FStar.UInt32.v len >= 2 then
    FStar.UInt32.uint_to_t (FStar.UInt32.v len - 2)
  else
    0ul

val body_bytes_after_stored_prefix : len:FStar.UInt32.t -> Tot FStar.UInt32.t
let body_bytes_after_stored_prefix len =
  if FStar.UInt32.v len >= 1 then
    FStar.UInt32.uint_to_t (FStar.UInt32.v len - 1)
  else
    0ul

val stored_prefix_high : hi:FStar.UInt8.t -> Tot FStar.UInt32.t
let stored_prefix_high hi =
  FStar.UInt32.uint_to_t (FStar.UInt8.v hi + 1)

val stored_prefix_high_value : acc:FStar.UInt32.t -> Tot nat
let stored_prefix_high_value acc =
  if FStar.UInt32.v acc > 0 && FStar.UInt32.v acc <= 256 then
    FStar.UInt32.v acc - 1
  else
    0

val u16_from_stored_high : acc:FStar.UInt32.t -> lo:FStar.UInt8.t -> Tot FStar.UInt16.t
let u16_from_stored_high acc lo =
  let hi = stored_prefix_high_value acc in
  assert (hi < 256);
  assert (FStar.UInt8.v lo < 256);
  FStar.UInt16.uint_to_t (Prims.op_Addition (Prims.op_Multiply hi 256) (FStar.UInt8.v lo))

val advance_message :
    expected:FStar.UInt16.t ->
    current:FStar.UInt32.t ->
    incoming:FStar.UInt32.t ->
    Tot stream_phase

let advance_message expected current incoming =
  let total_len = Prims.op_Addition (FStar.UInt32.v current) (FStar.UInt32.v incoming) in
  if total_len >= FStar.UInt16.v expected then
    Processing
  else
    begin
      assert (total_len < FStar.UInt16.v expected);
      assert (total_len < 65536);
      ReadingMessage (expected, FStar.UInt32.uint_to_t total_len)
    end

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
        FStar.UInt32.v len <= LowStar.Buffer.length data))
      (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let handle_stream_data ctx_ptr data len =
  let ctx = LowStar.Buffer.index ctx_ptr 0ul in
  match ctx.sc_phase with
  | ReadingLength acc ->
      if FStar.UInt32.v acc > 0 then
        if FStar.UInt32.v len >= 1 then
          begin
            assert (LowStar.Buffer.length data >= 1);
            let lo = LowStar.Buffer.index data 0ul in
            let expected = u16_from_stored_high acc lo in
            let body_len = body_bytes_after_stored_prefix len in
            advance_message expected 0ul body_len
          end
        else
          ctx.sc_phase
      else if FStar.UInt32.v len >= 2 then
        begin
          assert (LowStar.Buffer.length data >= 2);
          let expected = parse_u16_from_fragment data in
          let body_len = body_bytes_after_prefix len in
          advance_message expected 0ul body_len
        end
      else if FStar.UInt32.v len = 1 then
        begin
          assert (LowStar.Buffer.length data >= 1);
          let hi = LowStar.Buffer.index data 0ul in
          ReadingLength (stored_prefix_high hi)
        end
      else
        ctx.sc_phase
  | ReadingMessage (expected, current) ->
      advance_message expected current len
  | _ -> ctx.sc_phase

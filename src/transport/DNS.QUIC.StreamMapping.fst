module DNS.QUIC.StreamMapping

open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Modifies
open Steel.Memory
open Steel.ST.Util
open FStar.UInt16
open FStar.UInt32
open FStar.UInt64
module CAST = FStar.Int.Cast

(* The state machine for a single QUIC stream *)
type stream_phase =
  | ReadingLength
  | ReadingLengthHigh of (hi:FStar.UInt8.t)
  | ReadingMessage of
      (expected: FStar.UInt32.t{FStar.UInt32.v expected <= 65535} *
       current: FStar.UInt32.t)
  | AwaitingFin of (expected:FStar.UInt32.t{FStar.UInt32.v expected <= 65535})
  | Processing of (expected:FStar.UInt32.t{FStar.UInt32.v expected <= 65535})
  | Done

(* Caller-owned context. Calls must be serialized; no Steel permission is
   implemented by the compatibility interfaces. *)
noeq
type stream_context = {
  sc_id:    FStar.UInt64.t;
  sc_phase: stream_phase;
  sc_buf:   buffer FStar.UInt8.t;
}

(* --- Stream Multiplexing Logic --- *)

val u32_from_be_u16_bytes :
  hi:FStar.UInt8.t ->
  lo:FStar.UInt8.t ->
  Tot (n:FStar.UInt32.t{FStar.UInt32.v n <= 65535})
let u32_from_be_u16_bytes hi lo =
  let hi32 = CAST.uint8_to_uint32 hi in
  let lo32 = CAST.uint8_to_uint32 lo in
  assert (FStar.UInt32.v hi32 < 256);
  assert (FStar.UInt32.v lo32 < 256);
  let shifted = FStar.UInt32.shift_left hi32 8ul in
  assert (FStar.UInt32.v shifted <= 65280);
  assert (FStar.UInt32.v shifted + FStar.UInt32.v lo32 <= 65535);
  FStar.UInt32.add shifted lo32

val parse_u16_from_fragment :
    data:buffer FStar.UInt8.t ->
    Stack (n:FStar.UInt32.t{FStar.UInt32.v n <= 65535})
      (requires (fun h0 ->
        live h0 data /\
        LowStar.Buffer.length data >= 2))
      (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let parse_u16_from_fragment data =
  let hi = LowStar.Buffer.index data 0ul in
  let lo = LowStar.Buffer.index data 1ul in
  u32_from_be_u16_bytes hi lo

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

val advance_message :
    expected:FStar.UInt32.t{FStar.UInt32.v expected <= 65535} ->
    current:FStar.UInt32.t ->
    incoming:FStar.UInt32.t{
      FStar.UInt32.v current + FStar.UInt32.v incoming < 4294967296} ->
    Tot stream_phase

let advance_message expected current incoming =
  assert (FStar.UInt32.v current + FStar.UInt32.v incoming < 4294967296);
  let total_len = FStar.UInt32.add current incoming in
  if FStar.UInt32.gte total_len expected then
    AwaitingFin expected
  else
    begin
      assert (FStar.UInt32.v total_len < FStar.UInt32.v expected);
      ReadingMessage (expected, total_len)
    end

val remaining_message :
  expected:FStar.UInt32.t{FStar.UInt32.v expected <= 65535} ->
  current:FStar.UInt32.t ->
  Tot FStar.UInt32.t
let remaining_message expected current =
  if FStar.UInt32.gte current expected then
    0ul
  else
    begin
      assert (FStar.UInt32.v expected - FStar.UInt32.v current < 4294967296);
      FStar.UInt32.sub expected current
    end

val advance_message_checked :
    expected:FStar.UInt32.t{FStar.UInt32.v expected <= 65535} ->
    current:FStar.UInt32.t ->
    incoming:FStar.UInt32.t ->
    Tot stream_phase

let advance_message_checked expected current incoming =
  let remaining = remaining_message expected current in
  if FStar.UInt32.lt expected 12ul || FStar.UInt32.gt current expected ||
     FStar.UInt32.gt incoming remaining then
    Done
  else
    begin
      assert (FStar.UInt32.v incoming <= FStar.UInt32.v remaining);
      assert (FStar.UInt32.v current + FStar.UInt32.v incoming < 4294967296);
    advance_message expected current incoming
    end

let advance_body_phase (phase:stream_phase) (incoming:FStar.UInt32.t) : Tot stream_phase =
  match phase with
  | ReadingMessage (expected, current) -> advance_message_checked expected current incoming
  | AwaitingFin _ | Processing _ -> if FStar.UInt32.gt incoming 0ul then Done else phase
  | _ -> Done

let lemma_body_fragmentation
  (expected:FStar.UInt32.t{12 <= FStar.UInt32.v expected /\ FStar.UInt32.v expected <= 65535})
  (current:FStar.UInt32.t{FStar.UInt32.v current < FStar.UInt32.v expected})
  (a:FStar.UInt32.t) (b:FStar.UInt32.t{FStar.UInt32.v a + FStar.UInt32.v b < 4294967296})
  : Lemma (advance_body_phase (advance_message_checked expected current a) b ==
           advance_message_checked expected current (FStar.UInt32.add a b)) = ()

let fragment_phase (phase:stream_phase) (len:FStar.UInt32.t)
  (first:FStar.UInt8.t) (second:FStar.UInt8.t) : Tot stream_phase =
  match phase with
  | ReadingLengthHigh hi ->
      if FStar.UInt32.gte len 1ul then
        advance_message_checked (u32_from_be_u16_bytes hi first) 0ul
          (body_bytes_after_stored_prefix len)
      else phase
  | ReadingLength ->
      if FStar.UInt32.gte len 2ul then
        advance_message_checked (u32_from_be_u16_bytes first second) 0ul
          (body_bytes_after_prefix len)
      else if FStar.UInt32.eq len 1ul then ReadingLengthHigh first else phase
  | _ -> advance_body_phase phase len

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
      (ensures (fun h0 result h1 -> modifies_none h0 h1 /\
        result == fragment_phase ctx.sc_phase len
          (if FStar.UInt32.v len > 0 then FStar.Seq.index (as_seq h0 data) 0 else 0uy)
          (if FStar.UInt32.v len > 1 then FStar.Seq.index (as_seq h0 data) 1 else 0uy)))

let next_stream_phase ctx data len =
  let first = if FStar.UInt32.gt len 0ul then LowStar.Buffer.index data 0ul else 0uy in
  let second = if FStar.UInt32.gt len 1ul then LowStar.Buffer.index data 1ul else 0uy in
  fragment_phase ctx.sc_phase len first second

let finish_stream_phase (phase:stream_phase) : Tot stream_phase =
  match phase with
  | AwaitingFin expected -> Processing expected
  | Processing _ -> phase (* repeated notification of the same FIN *)
  | _ -> Done

let lemma_fin_requires_complete_message (phase:stream_phase)
  : Lemma (match finish_stream_phase phase with
           | Processing n -> phase == AwaitingFin n \/ phase == Processing n
           | _ -> True) = ()

let finish_doq_phase (phase:stream_phase) (id_hi:FStar.UInt8.t) (id_lo:FStar.UInt8.t)
  : Tot stream_phase =
  if FStar.UInt8.eq id_hi 0uy && FStar.UInt8.eq id_lo 0uy
  then finish_stream_phase phase else Done

val handle_stream_fin :
  ctx_ptr:buffer stream_context ->
  ST stream_phase
    (requires (fun h -> live h ctx_ptr /\ LowStar.Buffer.length ctx_ptr >= 1 /\
      (let ctx = FStar.Seq.index (as_seq h ctx_ptr) 0 in
       live h ctx.sc_buf /\ LowStar.Buffer.length ctx.sc_buf >= 2)))
    (ensures (fun h0 phase h1 ->
      modifies (loc_buffer ctx_ptr) h0 h1 /\ live h1 ctx_ptr /\
      (let ctx = FStar.Seq.index (as_seq h0 ctx_ptr) 0 in
       phase == finish_doq_phase ctx.sc_phase
         (FStar.Seq.index (as_seq h0 ctx.sc_buf) 0)
         (FStar.Seq.index (as_seq h0 ctx.sc_buf) 1)) /\
      FStar.Seq.index (as_seq h1 ctx_ptr) 0 ==
        { (FStar.Seq.index (as_seq h0 ctx_ptr) 0) with sc_phase = phase }))
let handle_stream_fin ctx_ptr =
  let ctx = LowStar.Buffer.index ctx_ptr 0ul in
  let hi = LowStar.Buffer.index ctx.sc_buf 0ul in
  let lo = LowStar.Buffer.index ctx.sc_buf 1ul in
  let phase = finish_doq_phase ctx.sc_phase hi lo in
  LowStar.Buffer.upd ctx_ptr 0ul { ctx with sc_phase = phase };
  phase

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
          let expected = u32_from_be_u16_bytes hi lo in
          let available = body_bytes_after_stored_prefix len in
          let wanted = remaining_message expected 0ul in
          let count = bounded_copy_len available wanted in
          if FStar.UInt32.gt count 0ul then
            begin
              assert (FStar.UInt32.v count <= FStar.UInt32.v available);
              assert (FStar.UInt32.v count <= FStar.UInt32.v expected);
              assert (FStar.UInt32.v count <= FStar.UInt32.v len - 1);
              assert (1 + FStar.UInt32.v count <= FStar.UInt32.v len);
              assert (1 + FStar.UInt32.v count <= LowStar.Buffer.length data);
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
              assert (FStar.UInt32.v count <= FStar.UInt32.v expected);
              assert (FStar.UInt32.v count <= FStar.UInt32.v len - 2);
              assert (2 + FStar.UInt32.v count <= FStar.UInt32.v len);
              assert (2 + FStar.UInt32.v count <= LowStar.Buffer.length data);
              LowStar.Buffer.blit data 2ul ctx.sc_buf 0ul count
            end
          else
            ()
        end
      else
        ()
  | ReadingMessage (expected, current) ->
      if FStar.UInt32.lt current expected then
        begin
          let wanted = remaining_message expected current in
          let count = bounded_copy_len len wanted in
          if FStar.UInt32.gt count 0ul then
            begin
              assert (FStar.UInt32.v count <= FStar.UInt32.v len);
              assert (FStar.UInt32.v count <= FStar.UInt32.v expected - FStar.UInt32.v current);
              assert (FStar.UInt32.v current + FStar.UInt32.v count <= FStar.UInt32.v expected);
              assert (FStar.UInt32.v expected <= 65535);
              assert (FStar.UInt32.v current + FStar.UInt32.v count <= LowStar.Buffer.length ctx.sc_buf);
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
      (ensures (fun h0 phase h1 ->
        (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
         modifies (loc_union (loc_buffer ctx_ptr) (loc_buffer ctx.sc_buf)) h0 h1 /\
         phase == fragment_phase ctx.sc_phase len
           (if FStar.UInt32.v len > 0 then FStar.Seq.index (as_seq h0 data) 0 else 0uy)
           (if FStar.UInt32.v len > 1 then FStar.Seq.index (as_seq h0 data) 1 else 0uy) /\
         FStar.Seq.index (as_seq h1 ctx_ptr) 0 == { ctx with sc_phase = phase }) /\
        live h1 ctx_ptr))

let handle_stream_data ctx_ptr data len =
  let ctx = LowStar.Buffer.index ctx_ptr 0ul in
  let phase = next_stream_phase ctx data len in
  copy_body_bytes ctx data len;
  let next_ctx = { ctx with sc_phase = phase } in
  LowStar.Buffer.upd ctx_ptr 0ul next_ctx;
  phase

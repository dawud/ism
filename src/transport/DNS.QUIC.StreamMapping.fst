module DNS.QUIC.StreamMapping

open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Modifies
open Steel.Memory
open Steel.ST.Util
open FStar.UInt16
open FStar.UInt32
open FStar.UInt64
module MODEL = DNS.QUIC.StreamModel

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

(* Keep the stable public datatype/C layout. Only this representation bridge is
   duplicated; both implementations execute the shared transition model. *)
inline_for_extraction
let to_model (phase:stream_phase) : MODEL.stream_phase =
  match phase with
  | ReadingLength -> MODEL.ReadingLength
  | ReadingLengthHigh hi -> MODEL.ReadingLengthHigh hi
  | ReadingMessage (expected, current) -> MODEL.ReadingMessage expected current
  | AwaitingFin expected -> MODEL.AwaitingFin expected
  | Processing expected -> MODEL.Processing expected
  | Done -> MODEL.Done

inline_for_extraction
let from_model (phase:MODEL.stream_phase) : stream_phase =
  match phase with
  | MODEL.ReadingLength -> ReadingLength
  | MODEL.ReadingLengthHigh hi -> ReadingLengthHigh hi
  | MODEL.ReadingMessage expected current -> ReadingMessage (expected, current)
  | MODEL.AwaitingFin expected -> AwaitingFin expected
  | MODEL.Processing expected -> Processing expected
  | MODEL.Done -> Done

let lemma_to_from_model (phase:MODEL.stream_phase)
  : Lemma (to_model (from_model phase) == phase) = ()

let lemma_from_to_model (phase:stream_phase)
  : Lemma (from_model (to_model phase) == phase) = ()

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
  MODEL.u32_from_be_u16_bytes hi lo

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
  MODEL.body_bytes_after_prefix len

val body_bytes_after_stored_prefix : len:FStar.UInt32.t -> Tot FStar.UInt32.t
let body_bytes_after_stored_prefix len =
  MODEL.body_bytes_after_stored_prefix len

val advance_message :
    expected:FStar.UInt32.t{FStar.UInt32.v expected <= 65535} ->
    current:FStar.UInt32.t ->
    incoming:FStar.UInt32.t{
      FStar.UInt32.v current + FStar.UInt32.v incoming < 4294967296} ->
    Tot stream_phase

let advance_message expected current incoming =
  from_model (MODEL.advance_message expected current incoming)

val remaining_message :
  expected:FStar.UInt32.t{FStar.UInt32.v expected <= 65535} ->
  current:FStar.UInt32.t ->
  Tot FStar.UInt32.t
let remaining_message expected current =
  MODEL.remaining_message expected current

val advance_message_checked :
    expected:FStar.UInt32.t{FStar.UInt32.v expected <= 65535} ->
    current:FStar.UInt32.t ->
    incoming:FStar.UInt32.t ->
    Tot stream_phase

let advance_message_checked expected current incoming =
  from_model (MODEL.advance_message_checked expected current incoming)

let advance_body_phase (phase:stream_phase) (incoming:FStar.UInt32.t) : Tot stream_phase =
  from_model (MODEL.advance_body_phase (to_model phase) incoming)

let lemma_body_fragmentation
  (expected:FStar.UInt32.t{12 <= FStar.UInt32.v expected /\ FStar.UInt32.v expected <= 65535})
  (current:FStar.UInt32.t{FStar.UInt32.v current < FStar.UInt32.v expected})
  (a:FStar.UInt32.t) (b:FStar.UInt32.t{FStar.UInt32.v a + FStar.UInt32.v b < 4294967296})
  : Lemma (advance_body_phase (advance_message_checked expected current a) b ==
           advance_message_checked expected current (FStar.UInt32.add a b)) =
  MODEL.lemma_body_fragmentation expected current a b;
  lemma_to_from_model (MODEL.advance_message_checked expected current a)

let fragment_phase (phase:stream_phase) (len:FStar.UInt32.t)
  (first:FStar.UInt8.t) (second:FStar.UInt8.t) : Tot stream_phase =
  from_model (MODEL.fragment_phase (to_model phase) len first second)

let lemma_fragment_matches_model (phase:stream_phase) (len:FStar.UInt32.t)
  (first second:FStar.UInt8.t)
  : Lemma (to_model (fragment_phase phase len first second) ==
           MODEL.fragment_phase (to_model phase) len first second) =
  lemma_to_from_model (MODEL.fragment_phase (to_model phase) len first second)

val bounded_copy_len : available:FStar.UInt32.t -> wanted:FStar.UInt32.t -> Tot FStar.UInt32.t
let bounded_copy_len available wanted =
  MODEL.bounded_copy_len available wanted

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
  from_model (MODEL.finish_stream_phase (to_model phase))

let lemma_fin_requires_complete_message (phase:stream_phase)
  : Lemma (match finish_stream_phase phase with
           | Processing n -> phase == AwaitingFin n \/ phase == Processing n
           | _ -> True) = ()

let finish_doq_phase (phase:stream_phase) (id_hi:FStar.UInt8.t) (id_lo:FStar.UInt8.t)
  : Tot stream_phase =
  from_model (MODEL.finish_doq_phase (to_model phase) id_hi id_lo)

let lemma_fin_matches_model (phase:stream_phase) (hi lo:FStar.UInt8.t)
  : Lemma (to_model (finish_doq_phase phase hi lo) ==
           MODEL.finish_doq_phase (to_model phase) hi lo) =
  lemma_to_from_model (MODEL.finish_doq_phase (to_model phase) hi lo)

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
        live h1 ctx.sc_buf /\
        (let first = if FStar.UInt32.v len > 0 then FStar.Seq.index (as_seq h0 data) 0 else 0uy in
         let second = if FStar.UInt32.v len > 1 then FStar.Seq.index (as_seq h0 data) 1 else 0uy in
         let plan = MODEL.fragment_copy_plan (to_model ctx.sc_phase) len first second in
         MODEL.copied_bytes (as_seq h0 ctx.sc_buf) (as_seq h0 data) (as_seq h1 ctx.sc_buf)
           (FStar.UInt32.v plan.MODEL.source_offset) (FStar.UInt32.v plan.MODEL.destination_offset)
           (FStar.UInt32.v plan.MODEL.count))))

let copy_body_bytes ctx data len =
  let h0 = FStar.HyperStack.ST.get () in
  let first = if FStar.UInt32.gt len 0ul then LowStar.Buffer.index data 0ul else 0uy in
  let second = if FStar.UInt32.gt len 1ul then LowStar.Buffer.index data 1ul else 0uy in
  let plan = MODEL.fragment_copy_plan (to_model ctx.sc_phase) len first second in
  (if FStar.UInt32.gt plan.MODEL.count 0ul then
    LowStar.Buffer.blit data plan.MODEL.source_offset ctx.sc_buf plan.MODEL.destination_offset plan.MODEL.count
  else ());
  let h1 = FStar.HyperStack.ST.get () in
  MODEL.lemma_copied_bytes_from_slices
    (as_seq h0 ctx.sc_buf) (as_seq h0 data) (as_seq h1 ctx.sc_buf)
    (FStar.UInt32.v plan.MODEL.source_offset) (FStar.UInt32.v plan.MODEL.destination_offset)
    (FStar.UInt32.v plan.MODEL.count)

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
         FStar.Seq.index (as_seq h1 ctx_ptr) 0 == { ctx with sc_phase = phase } /\
         (let first = if FStar.UInt32.v len > 0 then FStar.Seq.index (as_seq h0 data) 0 else 0uy in
          let second = if FStar.UInt32.v len > 1 then FStar.Seq.index (as_seq h0 data) 1 else 0uy in
          let plan = MODEL.fragment_copy_plan (to_model ctx.sc_phase) len first second in
          MODEL.copied_bytes (as_seq h0 ctx.sc_buf) (as_seq h0 data) (as_seq h1 ctx.sc_buf)
            (FStar.UInt32.v plan.MODEL.source_offset) (FStar.UInt32.v plan.MODEL.destination_offset)
            (FStar.UInt32.v plan.MODEL.count))) /\
        live h1 ctx_ptr))

let handle_stream_data ctx_ptr data len =
  let ctx = LowStar.Buffer.index ctx_ptr 0ul in
  let phase = next_stream_phase ctx data len in
  copy_body_bytes ctx data len;
  let next_ctx = { ctx with sc_phase = phase } in
  LowStar.Buffer.upd ctx_ptr 0ul next_ctx;
  phase

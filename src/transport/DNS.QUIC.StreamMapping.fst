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

(* Stateful accumulation of QUIC frames into DNS messages *)
val handle_stream_data : 
    ctx_ptr:buffer stream_context -> 
    data:buffer FStar.UInt8.t -> 
    len:FStar.UInt32.t -> 
    ST stream_phase
      (requires (fun h0 -> True)) 
      (ensures (fun h0 _ h1 -> True))

let handle_stream_data ctx_ptr data len =
  admit()

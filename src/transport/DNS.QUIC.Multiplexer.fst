module DNS.QUIC.Multiplexer

open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Modifies
open Steel.Memory
open Steel.ST.Util
open FStar.UInt32
open FStar.UInt64
open DNS.QUIC.StreamMapping

(* A Connection Context manages multiple streams *)
noeq
type connection_context = {
  cc_active: buffer (buffer stream_context);
  cc_num:    FStar.UInt32.t;
}

(* Find an existing stream context or return None *)
val find_stream : 
    conn:buffer connection_context -> 
    id:FStar.UInt64.t -> 
    ST (option (buffer stream_context))
      (requires (fun h0 -> True))
      (ensures (fun h0 _ h1 -> True))

let find_stream conn_ptr id =
  admit()

(* Allocate a new stream context for a new Stream ID *)
val allocate_stream : 
    conn:buffer connection_context -> 
    id:FStar.UInt64.t -> 
    ST (option (buffer stream_context))
      (requires (fun h0 -> True))
      (ensures (fun h0 _ h1 -> True))

let allocate_stream conn_ptr id =
  admit()

(* Cleanup a finished stream *)
val close_stream : 
    conn:buffer connection_context -> 
    id:FStar.UInt64.t -> 
    ST unit
      (requires (fun h0 -> True))
      (ensures (fun h0 _ h1 -> True))

let close_stream conn_ptr id =
  admit()

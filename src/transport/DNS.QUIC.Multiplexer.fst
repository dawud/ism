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
      (requires (fun h0 ->
        live h0 conn /\
        LowStar.Buffer.length conn >= 1 /\
        (let c = FStar.Seq.index (LowStar.Buffer.as_seq h0 conn) 0 in
         FStar.UInt32.v c.cc_num > 0 ==>
         live h0 c.cc_active /\
         LowStar.Buffer.length c.cc_active >= 1 /\
         (let stream_ptr = FStar.Seq.index (LowStar.Buffer.as_seq h0 c.cc_active) 0 in
          live h0 stream_ptr /\
          LowStar.Buffer.length stream_ptr >= 1))))
      (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let find_stream conn_ptr id =
  let conn = LowStar.Buffer.index conn_ptr 0ul in
  if FStar.UInt32.v conn.cc_num = 0 then
    None
  else
    let stream_ptr = LowStar.Buffer.index conn.cc_active 0ul in
    let stream = LowStar.Buffer.index stream_ptr 0ul in
    if stream.sc_id = id then Some stream_ptr else None

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

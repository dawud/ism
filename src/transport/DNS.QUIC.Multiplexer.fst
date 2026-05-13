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
  cc_capacity: FStar.UInt32.t;
}

val active_streams_live :
  h:FStar.Monotonic.HyperStack.mem ->
  active:buffer (buffer stream_context) ->
  count:FStar.UInt32.t ->
  Type0

let active_streams_live h active count =
  live h active /\
  FStar.UInt32.v count <= LowStar.Buffer.length active /\
  LowStar.Buffer.length active < 4294967296 /\
  (forall (i:nat).
    i < LowStar.Buffer.length active ==>
    (let stream_ptr = FStar.Seq.index (LowStar.Buffer.as_seq h active) i in
     live h stream_ptr /\
     LowStar.Buffer.length stream_ptr >= 1))

val find_stream_from :
  active:buffer (buffer stream_context) ->
  capacity:FStar.UInt32.t ->
  count:FStar.UInt32.t ->
  id:FStar.UInt64.t ->
  idx:FStar.UInt32.t{FStar.UInt32.v idx <= FStar.UInt32.v count} ->
  Stack (option (buffer stream_context))
    (requires (fun h0 ->
      active_streams_live h0 active capacity /\
      FStar.UInt32.v count <= FStar.UInt32.v capacity))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))
    (decreases (FStar.UInt32.v count - FStar.UInt32.v idx))

let rec find_stream_from active capacity count id idx =
  if FStar.UInt32.v idx = FStar.UInt32.v count then
    None
  else
    begin
      assert (FStar.UInt32.v idx < FStar.UInt32.v count);
      let stream_ptr = LowStar.Buffer.index active idx in
      let stream = LowStar.Buffer.index stream_ptr 0ul in
      if stream.sc_id = id then
        Some stream_ptr
      else
        begin
          assert (FStar.UInt32.v idx + 1 <= FStar.UInt32.v count);
          let next_idx = FStar.UInt32.uint_to_t (FStar.UInt32.v idx + 1) in
          find_stream_from active capacity count id next_idx
        end
    end

(* Find an existing stream context or return None *)
val find_stream : 
    conn:buffer connection_context -> 
    id:FStar.UInt64.t -> 
    ST (option (buffer stream_context))
      (requires (fun h0 ->
        live h0 conn /\
        LowStar.Buffer.length conn >= 1 /\
        (let c = FStar.Seq.index (LowStar.Buffer.as_seq h0 conn) 0 in
         FStar.UInt32.v c.cc_num <= FStar.UInt32.v c.cc_capacity /\
         (FStar.UInt32.v c.cc_num > 0 ==>
          active_streams_live h0 c.cc_active c.cc_capacity))))
      (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let find_stream conn_ptr id =
  let conn = LowStar.Buffer.index conn_ptr 0ul in
  if FStar.UInt32.v conn.cc_num = 0 then
    None
  else
    find_stream_from conn.cc_active conn.cc_capacity conn.cc_num id 0ul

(* Allocate a new stream context for a new Stream ID *)
val allocate_stream : 
    conn:buffer connection_context -> 
    id:FStar.UInt64.t -> 
    ST (option (buffer stream_context))
      (requires (fun h0 ->
        live h0 conn /\
        LowStar.Buffer.length conn >= 1 /\
        (let c = FStar.Seq.index (LowStar.Buffer.as_seq h0 conn) 0 in
         active_streams_live h0 c.cc_active c.cc_capacity /\
         FStar.UInt32.v c.cc_num <= FStar.UInt32.v c.cc_capacity)))
      (ensures (fun h0 _ h1 -> True))

let allocate_stream conn_ptr id =
  let conn = LowStar.Buffer.index conn_ptr 0ul in
  if FStar.UInt32.v conn.cc_num < FStar.UInt32.v conn.cc_capacity &&
     FStar.UInt32.v conn.cc_num < 4294967295 then
    let stream_ptr = LowStar.Buffer.index conn.cc_active conn.cc_num in
    let stream = LowStar.Buffer.index stream_ptr 0ul in
    let next_stream = { stream with sc_id = id; sc_phase = ReadingLength 0ul } in
    let next_count = FStar.UInt32.uint_to_t (FStar.UInt32.v conn.cc_num + 1) in
    LowStar.Buffer.upd stream_ptr 0ul next_stream;
    LowStar.Buffer.upd conn_ptr 0ul { conn with cc_num = next_count };
    Some stream_ptr
  else
    None

(* Cleanup a finished stream *)
val close_stream : 
    conn:buffer connection_context -> 
    id:FStar.UInt64.t -> 
    ST unit
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
      (ensures (fun h0 _ h1 ->
        modifies (loc_buffer conn) h0 h1 /\
        live h1 conn))

let close_stream conn_ptr id =
  let conn = LowStar.Buffer.index conn_ptr 0ul in
  if FStar.UInt32.v conn.cc_num = 0 then
    ()
  else
    let stream_ptr = LowStar.Buffer.index conn.cc_active 0ul in
    let stream = LowStar.Buffer.index stream_ptr 0ul in
    if stream.sc_id = id then
      LowStar.Buffer.upd conn_ptr 0ul { conn with cc_num = 0ul }
    else
      ()

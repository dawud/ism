module DNS.Worker

open FStar.HyperStack.ST
open LowStar.Buffer
open Steel.Memory
open Steel.ST.Util
open DNS.Protocol
open DNS.RCode
open DNS.QUIC.StreamMapping
open DNS.QUIC.Multiplexer

(* The Worker Harness *)
(* This loop represents a thread processing a single QUIC connection *)
val worker_loop : 
  conn:buffer connection_context -> 
  id:FStar.UInt64.t -> 
  ST unit
    (requires (fun h0 ->
      live h0 conn /\
      LowStar.Buffer.length conn >= 1 /\
      (let c = FStar.Seq.index (LowStar.Buffer.as_seq h0 conn) 0 in
       FStar.UInt32.v c.cc_num <= FStar.UInt32.v c.cc_capacity /\
       (if FStar.UInt32.v c.cc_num > 0 then
          active_streams_live h0 c.cc_active c.cc_capacity /\
          loc_disjoint (loc_buffer conn) (loc_buffer c.cc_active) /\
          (let stream_ptr = FStar.Seq.index (LowStar.Buffer.as_seq h0 c.cc_active) 0 in
           loc_disjoint (loc_buffer conn) (loc_buffer stream_ptr) /\
           loc_disjoint (loc_buffer c.cc_active) (loc_buffer stream_ptr))
        else True))))
    (ensures (fun h0 _ h1 -> True))

let worker_loop conn id =
  let c = LowStar.Buffer.index conn 0ul in
  if FStar.UInt32.v c.cc_num = 0 then
    ()
  else
    let ctx_ptr = LowStar.Buffer.index c.cc_active 0ul in
    let s = LowStar.Buffer.index ctx_ptr 0ul in
    if s.sc_id = id then
      match s.sc_phase with
      | Processing ->
          (* Response generation is not integrated yet; the verified bootstrap
             worker consumes the ready stream and closes the first-slot entry. *)
          LowStar.Buffer.upd ctx_ptr 0ul { s with sc_phase = Done };
          close_stream conn id
      | Done -> ()
      | _ -> ()
    else
      ()

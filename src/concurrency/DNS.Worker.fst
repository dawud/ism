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
          loc_disjoint (loc_buffer conn) (loc_buffer c.cc_active)
        else True))))
    (ensures (fun h0 _ h1 -> True))

let worker_loop conn id =
  let stream_opt = find_stream conn id in
  match stream_opt with
  | Some ctx_ptr ->
    let s = LowStar.Buffer.index ctx_ptr 0ul in
    begin
      match s.sc_phase with
      | Processing ->
          (* Response generation is not integrated yet; the verified bootstrap
             worker consumes the ready stream by closing the active entry. *)
          close_stream conn id
      | Done -> ()
      | _ -> ()
    end
  | None -> ()

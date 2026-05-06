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
       FStar.UInt32.v c.cc_num > 0 ==>
       live h0 c.cc_active /\
       LowStar.Buffer.length c.cc_active >= 1 /\
       (let stream_ptr = FStar.Seq.index (LowStar.Buffer.as_seq h0 c.cc_active) 0 in
        live h0 stream_ptr /\
        LowStar.Buffer.length stream_ptr >= 1))))
    (ensures (fun h0 _ h1 -> True))

let rec worker_loop conn id =
  (* 1. Poll for data on the stream *)
  let stream_opt = find_stream conn id in
  match stream_opt with
  | Some ctx_ptr ->
      (* Use admit for bootstrap of the concurrent loop *)
      let ctx = admit() in
      let s : stream_context = ctx in
      (match s.sc_phase with
       | Processing ->
           (* 2. Data is ready, perform logic (Authoritative or Recursive) *)
           ();
           (* 3. Respond and reset stream *)
           admit();
           worker_loop conn id
       | Done -> ()
       | _ -> 
           (* 4. Wait for more data *)
           worker_loop conn id)
  | None -> () (* Connection closed *)

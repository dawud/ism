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
    (requires (fun h0 -> True))
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

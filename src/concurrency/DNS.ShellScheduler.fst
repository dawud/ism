module DNS.ShellScheduler

open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Modifies
open DNS.QUIC.StreamMapping
open DNS.QUIC.Multiplexer
module COMPLETE = DNS.QUIC.MsQuicSendCompletion
module EGRESS = DNS.QUIC.MsQuicEgress
module INGRESS = DNS.QUIC.MsQuicIngress
module WORKER = DNS.Worker.Minimal

(* Scheduler-facing event shape for the unverified shell. The shell still owns
   polling, allocation, MsQuic callbacks, and queueing; this type only records
   the verified entry point selected for one already-checked event. *)
noeq
type shell_event =
  | AuthenticatedStreamData:
      ctx_ptr:buffer stream_context ->
      fragment:INGRESS.authenticated_stream_fragment ->
      shell_event
  | ProcessingReady:
      conn:buffer connection_context ->
      response_buffer:buffer FStar.UInt8.t ->
      response_capacity:FStar.UInt32.t ->
      stream_id:FStar.UInt64.t ->
      shell_event
  | ResponseSendFinished:
      conn:buffer connection_context ->
      descriptor:EGRESS.msquic_send_descriptor ->
      outcome:COMPLETE.msquic_send_outcome ->
      shell_event

val shell_event_live :
  h:FStar.Monotonic.HyperStack.mem ->
  event:shell_event ->
  Type0

let shell_event_live h event =
  match event with
  | AuthenticatedStreamData ctx_ptr fragment ->
      INGRESS.authenticated_stream_fragment_live h ctx_ptr fragment
  | ProcessingReady conn response_buffer response_capacity _stream_id ->
      live h conn /\
      LowStar.Buffer.length conn >= 1 /\
      live h response_buffer /\
      FStar.UInt32.v response_capacity <= LowStar.Buffer.length response_buffer /\
      loc_disjoint (loc_buffer conn) (loc_buffer response_buffer) /\
      (let c = FStar.Seq.index (LowStar.Buffer.as_seq h conn) 0 in
       FStar.UInt32.v c.cc_num <= FStar.UInt32.v c.cc_capacity /\
       (if FStar.UInt32.v c.cc_num > 0 then
          active_streams_live h c.cc_active c.cc_capacity /\
          loc_disjoint (loc_buffer conn) (loc_buffer c.cc_active)
        else True))
  | ResponseSendFinished conn descriptor _outcome ->
      COMPLETE.send_descriptor_live h descriptor /\
      live h conn /\
      LowStar.Buffer.length conn >= 1 /\
      (let c = FStar.Seq.index (LowStar.Buffer.as_seq h conn) 0 in
       FStar.UInt32.v c.cc_num <= FStar.UInt32.v c.cc_capacity /\
       (FStar.UInt32.v c.cc_num > 0 ==>
        active_streams_live h c.cc_active c.cc_capacity /\
        loc_disjoint (loc_buffer conn) (loc_buffer c.cc_active)))

val dispatch_shell_event :
  auth:INGRESS.msquic_authenticated ->
  stream_borrow:INGRESS.msquic_stream_borrow ->
  completion_borrow:COMPLETE.msquic_send_completion_borrow ->
  event:shell_event ->
  ST unit
    (requires (fun h0 ->
      shell_event_live h0 event))
    (ensures (fun h0 _ h1 ->
      match event with
      | AuthenticatedStreamData ctx_ptr _fragment ->
          (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
           modifies (loc_union (loc_buffer ctx_ptr) (loc_buffer ctx.sc_buf)) h0 h1) /\
          live h1 ctx_ptr
      | ProcessingReady _conn _response_buffer _response_capacity _stream_id -> True
      | ResponseSendFinished _conn _descriptor _outcome -> True))

let dispatch_shell_event auth stream_borrow completion_borrow event =
  match event with
  | AuthenticatedStreamData ctx_ptr fragment ->
      let _phase =
        INGRESS.handle_authenticated_stream_fragment
          auth
          stream_borrow
          ctx_ptr
          fragment in
      ()
  | ProcessingReady conn response_buffer response_capacity stream_id ->
      let _ =
        match find_stream conn stream_id with
        | Some ctx_ptr ->
            let stream = LowStar.Buffer.index ctx_ptr 0ul in
            begin match stream.sc_phase with
            | Processing request_len ->
                WORKER.prepare_worker_minimal_error_response_send
                  ctx_ptr
                  response_buffer
                  response_capacity
                  request_len
            | _ -> 0ul
            end
        | None -> 0ul in
      ()
  | ResponseSendFinished conn descriptor outcome ->
      COMPLETE.complete_response_send completion_borrow conn descriptor outcome

val dispatch_authenticated_stream_data_event :
  ctx_ptr:buffer stream_context ->
  stream_id:FStar.UInt64.t ->
  data:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  ST stream_phase
    (requires (fun h0 ->
      INGRESS.authenticated_stream_fragment_live h0 ctx_ptr {
        INGRESS.msif_stream_id = stream_id;
        INGRESS.msif_data = data;
        INGRESS.msif_len = len;
        INGRESS.msif_fin = false;
      }))
    (ensures (fun h0 _ h1 ->
      (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
       modifies (loc_union (loc_buffer ctx_ptr) (loc_buffer ctx.sc_buf)) h0 h1) /\
      live h1 ctx_ptr))

let dispatch_authenticated_stream_data_event ctx_ptr stream_id data len =
  let fragment = {
    INGRESS.msif_stream_id = stream_id;
    INGRESS.msif_data = data;
    INGRESS.msif_len = len;
    INGRESS.msif_fin = false;
  } in
  INGRESS.handle_authenticated_stream_fragment () () ctx_ptr fragment

val dispatch_minimal_worker_error_response_event :
  conn:buffer connection_context ->
  response_buffer:buffer FStar.UInt8.t ->
  response_capacity:FStar.UInt32.t ->
  stream_id:FStar.UInt64.t ->
  ST FStar.UInt32.t
    (requires (fun h0 ->
      live h0 conn /\
      LowStar.Buffer.length conn >= 1 /\
      live h0 response_buffer /\
      FStar.UInt32.v response_capacity <= LowStar.Buffer.length response_buffer /\
      loc_disjoint (loc_buffer conn) (loc_buffer response_buffer) /\
      (let c = FStar.Seq.index (LowStar.Buffer.as_seq h0 conn) 0 in
       FStar.UInt32.v c.cc_num <= FStar.UInt32.v c.cc_capacity /\
       (if FStar.UInt32.v c.cc_num > 0 then
          active_streams_live h0 c.cc_active c.cc_capacity /\
          loc_disjoint (loc_buffer conn) (loc_buffer c.cc_active)
        else True))))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer response_buffer) h0 h1 /\
      live h1 response_buffer))

let dispatch_minimal_worker_error_response_event conn response_buffer response_capacity stream_id =
  match find_stream conn stream_id with
  | Some ctx_ptr ->
      let stream = LowStar.Buffer.index ctx_ptr 0ul in
      begin match stream.sc_phase with
      | Processing request_len ->
          WORKER.prepare_worker_minimal_error_response_send
            ctx_ptr
            response_buffer
            response_capacity
            request_len
      | _ -> 0ul
      end
  | None -> 0ul

val dispatch_empty_noerror_response_event :
  conn:buffer connection_context ->
  response_buffer:buffer FStar.UInt8.t ->
  response_capacity:FStar.UInt32.t ->
  stream_id:FStar.UInt64.t ->
  ST FStar.UInt32.t
    (requires (fun h0 ->
      live h0 conn /\
      LowStar.Buffer.length conn >= 1 /\
      live h0 response_buffer /\
      FStar.UInt32.v response_capacity <= LowStar.Buffer.length response_buffer /\
      loc_disjoint (loc_buffer conn) (loc_buffer response_buffer) /\
      (let c = FStar.Seq.index (LowStar.Buffer.as_seq h0 conn) 0 in
       FStar.UInt32.v c.cc_num <= FStar.UInt32.v c.cc_capacity /\
       (if FStar.UInt32.v c.cc_num > 0 then
          active_streams_live h0 c.cc_active c.cc_capacity /\
          loc_disjoint (loc_buffer conn) (loc_buffer c.cc_active)
        else True))))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer response_buffer) h0 h1 /\
      live h1 response_buffer))

let dispatch_empty_noerror_response_event conn response_buffer response_capacity stream_id =
  match find_stream conn stream_id with
  | Some ctx_ptr ->
      let stream = LowStar.Buffer.index ctx_ptr 0ul in
      begin match stream.sc_phase with
      | Processing request_len ->
          WORKER.prepare_worker_empty_noerror_response_send
            ctx_ptr
            response_buffer
            response_capacity
            request_len
      | _ -> 0ul
      end
  | None -> 0ul

val dispatch_validated_minimal_response_event :
  conn:buffer connection_context ->
  response_buffer:buffer FStar.UInt8.t ->
  response_capacity:FStar.UInt32.t ->
  stream_id:FStar.UInt64.t ->
  ST FStar.UInt32.t
    (requires (fun h0 ->
      live h0 conn /\
      LowStar.Buffer.length conn >= 1 /\
      live h0 response_buffer /\
      FStar.UInt32.v response_capacity <= LowStar.Buffer.length response_buffer /\
      loc_disjoint (loc_buffer conn) (loc_buffer response_buffer) /\
      (let c = FStar.Seq.index (LowStar.Buffer.as_seq h0 conn) 0 in
       FStar.UInt32.v c.cc_num <= FStar.UInt32.v c.cc_capacity /\
       (if FStar.UInt32.v c.cc_num > 0 then
          active_streams_live h0 c.cc_active c.cc_capacity /\
          loc_disjoint (loc_buffer conn) (loc_buffer c.cc_active)
        else True))))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer response_buffer) h0 h1 /\
      live h1 response_buffer))

let dispatch_validated_minimal_response_event conn response_buffer response_capacity stream_id =
  match find_stream conn stream_id with
  | Some ctx_ptr ->
      let stream = LowStar.Buffer.index ctx_ptr 0ul in
      begin match stream.sc_phase with
      | Processing request_len ->
          WORKER.prepare_worker_validated_minimal_response_send
            ctx_ptr
            response_buffer
            response_capacity
            request_len
      | _ -> 0ul
      end
  | None -> 0ul

val dispatch_response_send_finished_for_stream_event :
  conn:buffer connection_context ->
  response_buffer:buffer FStar.UInt8.t ->
  response_len:FStar.UInt32.t ->
  stream_id:FStar.UInt64.t ->
  outcome_code:FStar.UInt8.t ->
  ST FStar.UInt8.t
    (requires (fun h0 ->
      live h0 conn /\
      LowStar.Buffer.length conn >= 1 /\
      live h0 response_buffer /\
      FStar.UInt32.v response_len <= LowStar.Buffer.length response_buffer /\
      (let c = FStar.Seq.index (LowStar.Buffer.as_seq h0 conn) 0 in
       FStar.UInt32.v c.cc_num <= FStar.UInt32.v c.cc_capacity /\
       (FStar.UInt32.v c.cc_num > 0 ==>
        active_streams_live h0 c.cc_active c.cc_capacity /\
        loc_disjoint (loc_buffer conn) (loc_buffer c.cc_active)))))
    (ensures (fun _h0 _ _h1 -> True))

let dispatch_response_send_finished_for_stream_event
  conn
  response_buffer
  response_len
  stream_id
  outcome_code =
  let descriptor = {
    EGRESS.mssd_stream_id = stream_id;
    EGRESS.mssd_data = response_buffer;
    EGRESS.mssd_len = response_len;
    EGRESS.mssd_fin = true;
  } in
  let outcome =
    if FStar.UInt8.eq outcome_code 0uy then
      COMPLETE.SendCompleted
    else
      COMPLETE.SendDropped in
  COMPLETE.complete_response_send () conn descriptor outcome;
  1uy

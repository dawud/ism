module DNS.ShellBoundary

open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Modifies
module MUX = DNS.QUIC.Multiplexer
module SCHED = DNS.ShellScheduler
module STREAM = DNS.QUIC.StreamMapping
module WORKER = DNS.Worker.Minimal

(* C-facing phase codes for the unverified shell. Keep this stable and small:
   the richer F* stream_phase type stays inside the verified core. *)
val shell_phase_code : phase:STREAM.stream_phase -> Tot FStar.UInt8.t
let shell_phase_code phase =
  match phase with
  | STREAM.ReadingLength -> 0uy
  | STREAM.ReadingLengthHigh _ -> 0uy
  | STREAM.ReadingMessage _ -> 1uy
  | STREAM.Processing _ -> 2uy
  | STREAM.Done -> 3uy

(* First stable shell boundary: authenticated MsQuic stream bytes entering the
   verified DoQ length-framing state machine. The shell is responsible for the
   authentication, stream ownership, and lifetime assumptions encoded here. *)
val dispatch_authenticated_stream_data :
  ctx_ptr:buffer STREAM.stream_context ->
  stream_id:FStar.UInt64.t ->
  data:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  ST FStar.UInt8.t
    (requires (fun h0 ->
      live h0 ctx_ptr /\
      LowStar.Buffer.length ctx_ptr >= 1 /\
      live h0 data /\
      FStar.UInt32.v len <= LowStar.Buffer.length data /\
      (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
       ctx.STREAM.sc_id = stream_id /\
       live h0 ctx.STREAM.sc_buf /\
       LowStar.Buffer.length ctx.STREAM.sc_buf >= 65535 /\
       disjoint data ctx.STREAM.sc_buf /\
       loc_disjoint (loc_buffer ctx_ptr) (loc_buffer ctx.STREAM.sc_buf))))
    (ensures (fun h0 _ h1 ->
      (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
       modifies (loc_union (loc_buffer ctx_ptr) (loc_buffer ctx.STREAM.sc_buf)) h0 h1) /\
      live h1 ctx_ptr))

let dispatch_authenticated_stream_data ctx_ptr stream_id data len =
  let _ = stream_id in
  let phase = STREAM.handle_stream_data ctx_ptr data len in
  shell_phase_code phase

(* C-facing minimal worker error-response boundary. The shell only calls this
   after stream ingestion returns Processing for the matching stream. *)
val process_ready_stream_for_response :
  conn:buffer MUX.connection_context ->
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
       FStar.UInt32.v c.MUX.cc_num <= FStar.UInt32.v c.MUX.cc_capacity /\
       (if FStar.UInt32.v c.MUX.cc_num > 0 then
          MUX.active_streams_live h0 c.MUX.cc_active c.MUX.cc_capacity /\
          loc_disjoint (loc_buffer conn) (loc_buffer c.MUX.cc_active)
        else True))))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer response_buffer) h0 h1 /\
      live h1 response_buffer))

let process_ready_stream_for_response conn response_buffer response_capacity stream_id =
  match MUX.find_stream conn stream_id with
  | Some ctx_ptr ->
      let stream = LowStar.Buffer.index ctx_ptr 0ul in
      begin match stream.STREAM.sc_phase with
      | STREAM.Processing request_len ->
          WORKER.prepare_worker_minimal_error_response_send
            ctx_ptr
            response_buffer
            response_capacity
            request_len
      | _ -> 0ul
      end
  | None -> 0ul

val process_ready_stream_for_empty_response :
  conn:buffer MUX.connection_context ->
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
       FStar.UInt32.v c.MUX.cc_num <= FStar.UInt32.v c.MUX.cc_capacity /\
       (if FStar.UInt32.v c.MUX.cc_num > 0 then
          MUX.active_streams_live h0 c.MUX.cc_active c.MUX.cc_capacity /\
          loc_disjoint (loc_buffer conn) (loc_buffer c.MUX.cc_active)
        else True))))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer response_buffer) h0 h1 /\
      live h1 response_buffer))

let process_ready_stream_for_empty_response conn response_buffer response_capacity stream_id =
  match MUX.find_stream conn stream_id with
  | Some ctx_ptr ->
      let stream = LowStar.Buffer.index ctx_ptr 0ul in
      begin match stream.STREAM.sc_phase with
      | STREAM.Processing request_len ->
          WORKER.prepare_worker_empty_noerror_response_send
            ctx_ptr
            response_buffer
            response_capacity
            request_len
      | _ -> 0ul
      end
  | None -> 0ul

val process_ready_stream_for_validated_minimal_response :
  conn:buffer MUX.connection_context ->
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
       FStar.UInt32.v c.MUX.cc_num <= FStar.UInt32.v c.MUX.cc_capacity /\
       (if FStar.UInt32.v c.MUX.cc_num > 0 then
          MUX.active_streams_live h0 c.MUX.cc_active c.MUX.cc_capacity /\
          loc_disjoint (loc_buffer conn) (loc_buffer c.MUX.cc_active)
        else True))))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer response_buffer) h0 h1 /\
      live h1 response_buffer))

let process_ready_stream_for_validated_minimal_response conn response_buffer response_capacity stream_id =
  match MUX.find_stream conn stream_id with
  | Some ctx_ptr ->
      let stream = LowStar.Buffer.index ctx_ptr 0ul in
      begin match stream.STREAM.sc_phase with
      | STREAM.Processing request_len ->
          WORKER.prepare_worker_validated_minimal_response_send
            ctx_ptr
            response_buffer
            response_capacity
            request_len
      | _ -> 0ul
      end
  | None -> 0ul

(* Stable C-facing wrappers that route shell-selected events through the
   scheduler without exposing the rich F* shell_event union at the ABI. *)
val dispatch_authenticated_stream_data_via_scheduler :
  ctx_ptr:buffer STREAM.stream_context ->
  stream_id:FStar.UInt64.t ->
  data:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  ST FStar.UInt8.t
    (requires (fun h0 ->
      live h0 ctx_ptr /\
      LowStar.Buffer.length ctx_ptr >= 1 /\
      live h0 data /\
      FStar.UInt32.v len <= LowStar.Buffer.length data /\
      (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
       ctx.STREAM.sc_id = stream_id /\
       live h0 ctx.STREAM.sc_buf /\
       LowStar.Buffer.length ctx.STREAM.sc_buf >= 65535 /\
       disjoint data ctx.STREAM.sc_buf /\
       loc_disjoint (loc_buffer ctx_ptr) (loc_buffer ctx.STREAM.sc_buf))))
    (ensures (fun h0 _ h1 ->
      (let ctx = FStar.Seq.index (LowStar.Buffer.as_seq h0 ctx_ptr) 0 in
       modifies (loc_union (loc_buffer ctx_ptr) (loc_buffer ctx.STREAM.sc_buf)) h0 h1) /\
      live h1 ctx_ptr))

let dispatch_authenticated_stream_data_via_scheduler ctx_ptr stream_id data len =
  let phase =
    SCHED.dispatch_authenticated_stream_data_event
      ctx_ptr
      stream_id
      data
      len in
  shell_phase_code phase

val dispatch_ready_stream_for_response_via_scheduler :
  conn:buffer MUX.connection_context ->
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
       FStar.UInt32.v c.MUX.cc_num <= FStar.UInt32.v c.MUX.cc_capacity /\
       (if FStar.UInt32.v c.MUX.cc_num > 0 then
          MUX.active_streams_live h0 c.MUX.cc_active c.MUX.cc_capacity /\
          loc_disjoint (loc_buffer conn) (loc_buffer c.MUX.cc_active)
        else True))))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer response_buffer) h0 h1 /\
      live h1 response_buffer))

let dispatch_ready_stream_for_response_via_scheduler
  conn
  response_buffer
  response_capacity
  stream_id =
  SCHED.dispatch_minimal_worker_error_response_event
    conn
    response_buffer
    response_capacity
    stream_id

val dispatch_ready_stream_for_empty_response_via_scheduler :
  conn:buffer MUX.connection_context ->
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
       FStar.UInt32.v c.MUX.cc_num <= FStar.UInt32.v c.MUX.cc_capacity /\
       (if FStar.UInt32.v c.MUX.cc_num > 0 then
          MUX.active_streams_live h0 c.MUX.cc_active c.MUX.cc_capacity /\
          loc_disjoint (loc_buffer conn) (loc_buffer c.MUX.cc_active)
        else True))))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer response_buffer) h0 h1 /\
      live h1 response_buffer))

let dispatch_ready_stream_for_empty_response_via_scheduler
  conn
  response_buffer
  response_capacity
  stream_id =
  SCHED.dispatch_empty_noerror_response_event
    conn
    response_buffer
    response_capacity
    stream_id

val dispatch_ready_stream_for_validated_minimal_response_via_scheduler :
  conn:buffer MUX.connection_context ->
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
       FStar.UInt32.v c.MUX.cc_num <= FStar.UInt32.v c.MUX.cc_capacity /\
       (if FStar.UInt32.v c.MUX.cc_num > 0 then
          MUX.active_streams_live h0 c.MUX.cc_active c.MUX.cc_capacity /\
          loc_disjoint (loc_buffer conn) (loc_buffer c.MUX.cc_active)
        else True))))
    (ensures (fun h0 _ h1 ->
      modifies (loc_buffer response_buffer) h0 h1 /\
      live h1 response_buffer))

let dispatch_ready_stream_for_validated_minimal_response_via_scheduler
  conn
  response_buffer
  response_capacity
  stream_id =
  SCHED.dispatch_validated_minimal_response_event
    conn
    response_buffer
    response_capacity
    stream_id

val dispatch_response_send_finished_via_scheduler :
  conn:buffer MUX.connection_context ->
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
       FStar.UInt32.v c.MUX.cc_num <= FStar.UInt32.v c.MUX.cc_capacity /\
       (FStar.UInt32.v c.MUX.cc_num > 0 ==>
        MUX.active_streams_live h0 c.MUX.cc_active c.MUX.cc_capacity /\
        loc_disjoint (loc_buffer conn) (loc_buffer c.MUX.cc_active)))))
    (ensures (fun _h0 _ _h1 -> True))

let dispatch_response_send_finished_via_scheduler
  conn
  response_buffer
  response_len
  stream_id
  outcome_code =
  SCHED.dispatch_response_send_finished_for_stream_event
    conn
    response_buffer
    response_len
    stream_id
    outcome_code

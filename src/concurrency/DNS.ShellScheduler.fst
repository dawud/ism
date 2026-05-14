module DNS.ShellScheduler

open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Modifies
open DNS.QUIC.StreamMapping
open DNS.QUIC.Multiplexer
module COMPLETE = DNS.QUIC.MsQuicSendCompletion
module EGRESS = DNS.QUIC.MsQuicEgress
module INGRESS = DNS.QUIC.MsQuicIngress
module WORKER = DNS.Worker

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
    (ensures (fun _h0 _ _h1 -> True))

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
      WORKER.worker_loop conn response_buffer response_capacity stream_id
  | ResponseSendFinished conn descriptor outcome ->
      COMPLETE.complete_response_send completion_borrow conn descriptor outcome

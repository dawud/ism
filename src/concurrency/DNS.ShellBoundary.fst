module DNS.ShellBoundary

open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Modifies
module STREAM = DNS.QUIC.StreamMapping

(* C-facing phase codes for the unverified shell. Keep this stable and small:
   the richer F* stream_phase type stays inside the verified core. *)
val shell_phase_code : phase:STREAM.stream_phase -> Tot FStar.UInt8.t
let shell_phase_code phase =
  match phase with
  | STREAM.ReadingLength _ -> 0uy
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

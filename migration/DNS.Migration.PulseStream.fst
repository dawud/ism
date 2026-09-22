module DNS.Migration.PulseStream
#lang-pulse

open Pulse.Lib.Pervasives
module A = Pulse.Lib.Array
module R = Pulse.Lib.Reference
module S = FStar.Seq
module G = FStar.Ghost
module SZ = FStar.SizeT
module U8 = FStar.UInt8
module U32 = FStar.UInt32
module U64 = FStar.UInt64
module M = DNS.QUIC.StreamModel
open Pulse.Lib.Array

noeq
type stream_context = {
  sc_id: U64.t;
  sc_phase: M.stream_phase;
  sc_buf: A.array U8.t;
}

(* This is a sequential boundary over caller-owned storage. Separation, not
   unit borrow tokens, supplies permission to mutate context and message bytes.
   No allocation/free, authentication axiom, or assumed ownership is used. *)
fn copy_range (src dst:A.array U8.t) (source destination count:SZ.t)
  (#src0 #dst0:G.erased (S.seq U8.t))
requires A.pts_to src src0 ** A.pts_to dst dst0
requires pure (SZ.v source + SZ.v count <= S.length src0 /\
               SZ.v destination + SZ.v count <= S.length dst0)
ensures exists* out.
  A.pts_to src src0 ** A.pts_to dst out **
  pure (M.copied_bytes dst0 src0 out (SZ.v source) (SZ.v destination) (SZ.v count))
{
  A.pts_to_len src;
  A.pts_to_len dst;
  let mut i = 0sz;
  while (SZ.lt !i count)
  invariant exists* (vi:SZ.t) (out:S.seq U8.t).
    R.pts_to i vi ** A.pts_to src src0 ** A.pts_to dst out **
    pure (SZ.v vi <= SZ.v count /\
      M.copied_bytes dst0 src0 out (SZ.v source) (SZ.v destination) (SZ.v vi))
  decreases (SZ.v count - SZ.v !i)
  {
    let vi = !i;
    let from = SZ.add source vi;
    let into = SZ.add destination vi;
    let byte = src.(from);
    dst.(into) <- byte;
    i := SZ.add vi 1sz;
  };
  ()
}

fn handle_stream_data (ctx_ptr:R.ref stream_context) (data:A.array U8.t) (len:U32.t)
  (#ctx:G.erased stream_context) (#input #before:G.erased (S.seq U8.t))
requires R.pts_to ctx_ptr ctx ** A.pts_to ctx.sc_buf before ** A.pts_to data input
requires pure (65535 <= S.length before /\ U32.v len <= S.length input)
returns phase:M.stream_phase
ensures exists* after.
  R.pts_to ctx_ptr ({ctx with sc_phase = phase}) **
  A.pts_to ctx.sc_buf after ** A.pts_to data input **
  pure (
    let first = if U32.v len > 0 then S.index input 0 else 0uy in
    let second = if U32.v len > 1 then S.index input 1 else 0uy in
    let plan = M.fragment_copy_plan ctx.sc_phase len first second in
    phase == M.fragment_phase ctx.sc_phase len first second /\
    (M.valid_phase ctx.sc_phase ==> M.valid_phase phase) /\
    M.copied_bytes before input after
      (U32.v plan.source_offset) (U32.v plan.destination_offset) (U32.v plan.count))
{
  let state = !ctx_ptr;
  let first = if (U32.gt len 0ul) { data.(0sz) } else { 0uy };
  let second = if (U32.gt len 1ul) { data.(1sz) } else { 0uy };
  let phase = M.fragment_phase state.sc_phase len first second;
  let plan = M.fragment_copy_plan state.sc_phase len first second;
  copy_range data state.sc_buf
    (SZ.uint32_to_sizet plan.source_offset)
    (SZ.uint32_to_sizet plan.destination_offset)
    (SZ.uint32_to_sizet plan.count);
  if (M.valid_phase state.sc_phase) {
    M.lemma_fragment_preserves_valid_phase state.sc_phase len first second;
    ()
  };
  ctx_ptr := {state with sc_phase = phase};
  phase
}

fn handle_stream_fin (ctx_ptr:R.ref stream_context)
  (#ctx:G.erased stream_context)
  (#bytes:G.erased (b:S.seq U8.t{2 <= S.length b}))
requires R.pts_to ctx_ptr ctx ** A.pts_to ctx.sc_buf bytes
requires pure (2 <= S.length bytes)
returns phase:M.stream_phase
ensures R.pts_to ctx_ptr ({ctx with sc_phase = phase}) ** A.pts_to ctx.sc_buf bytes **
  pure (phase == M.finish_doq_phase ctx.sc_phase (S.index bytes 0) (S.index bytes 1) /\
        (M.valid_phase ctx.sc_phase ==> M.valid_phase phase))
{
  let state = !ctx_ptr;
  let hi = state.sc_buf.(0sz);
  let lo = state.sc_buf.(1sz);
  let phase = M.finish_doq_phase state.sc_phase hi lo;
  if (M.valid_phase state.sc_phase) {
    M.lemma_fin_preserves_valid_phase state.sc_phase hi lo;
    ()
  };
  ctx_ptr := {state with sc_phase = phase};
  phase
}

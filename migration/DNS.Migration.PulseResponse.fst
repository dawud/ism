module DNS.Migration.PulseResponse
#lang-pulse

open Pulse.Lib.Pervasives
open Pulse.Lib.Array
module A = Pulse.Lib.Array
module S = FStar.Seq
module G = FStar.Ghost
module U8 = FStar.UInt8
module U32 = FStar.UInt32
module SZ = FStar.SizeT
module M = DNS.QUIC.ResponseModel
module P = DNS.Migration.PulseStream

(* Synchronous framing into separate caller-owned storage. Contexts, messages
   and unrelated resources are framed; this does not submit a send or retain
   a borrow across a callback. The source is preserved even on rejection. *)
fn frame_response (response destination:A.array U8.t) (length capacity:U32.t)
  (#input #before:G.erased (S.seq U8.t))
requires A.pts_to response input ** A.pts_to destination before
requires pure (U32.v length <= S.length input /\ U32.v capacity <= S.length before)
returns result:U32.t
ensures exists* after.
  A.pts_to response input ** A.pts_to destination after **
  pure (M.framing_result before input after length capacity result)
{
  let framed = M.framed_length length capacity;
  if (U32.eq framed 0ul) {
    0ul
  } else {
    A.pts_to_len destination;
    let hi = M.prefix_hi length;
    let lo = M.prefix_lo length;
    destination.(0sz) <- hi;
    destination.(1sz) <- lo;
    P.copy_range response destination 0sz 2sz (SZ.uint32_to_sizet length);
    framed
  }
}

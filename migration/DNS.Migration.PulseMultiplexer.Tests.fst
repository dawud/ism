module DNS.Migration.PulseMultiplexer.Tests
#lang-pulse
(* Chained exact snapshots/permutations require more SMT fuel than one-step tests. *)
#set-options "--z3rlimit 100"

open Pulse.Lib.Pervasives
open Pulse.Lib.Array
module A = Pulse.Lib.Array
module R = Pulse.Lib.Reference
module S = FStar.Seq
module G = FStar.Ghost
module U32 = FStar.UInt32
module P = DNS.Migration.PulseStream
module M = DNS.Migration.PulseMultiplexer
module T = DNS.QUIC.TableModel
module F = DNS.QUIC.StreamModel

let pair (a b:M.slot) = S.cons a (S.cons b S.empty)
let pair_state (a:M.slot) (va vb:P.stream_context) : GTot M.snapshot =
  fun p -> if Prims.t2b (p == a) then va else vb

ghost
fn distinct_from_ids (a b:M.slot) (#va #vb:G.erased P.stream_context)
requires R.pts_to a va ** R.pts_to b vb ** pure (va.P.sc_id <> vb.P.sc_id)
ensures R.pts_to a va ** R.pts_to b vb ** pure (a =!= b)
{
  let same = Prims.t2b (a == b);
  if (same) {
    rewrite R.pts_to b vb as R.pts_to a vb;
    R.pts_to_injective_eq #P.stream_context #1.0R #1.0R #va #vb a;
    unreachable();
  };
}

ghost
fn own_pair (a b:M.slot) (#va #vb:G.erased P.stream_context)
requires R.pts_to a va ** R.pts_to b vb ** pure (a =!= b)
ensures M.contexts (pair a b) (pair_state a va vb)
{
  let state = G.hide (pair_state a va vb);
  rewrite emp as M.contexts_from (pair a b) state 2 2;
  rewrite R.pts_to b vb as R.pts_to (S.index (pair a b) 1) ((G.reveal state) (S.index (pair a b) 1));
  rewrite (R.pts_to (S.index (pair a b) 1) ((G.reveal state) (S.index (pair a b) 1)) **
    M.contexts_from (pair a b) state 2 2) as M.contexts_from (pair a b) state 1 2;
  rewrite R.pts_to a va as R.pts_to (S.index (pair a b) 0) ((G.reveal state) (S.index (pair a b) 0));
  rewrite (R.pts_to (S.index (pair a b) 0) ((G.reveal state) (S.index (pair a b) 0)) **
    M.contexts_from (pair a b) state 1 2) as M.contexts_from (pair a b) state 0 2;
  rewrite M.contexts_from (pair a b) state 0 2 as M.contexts (pair a b) state;
  rewrite M.contexts (pair a b) state as M.contexts (pair a b) (pair_state a va vb);
}

ghost
fn release_pair (a b:M.slot) (#state:G.erased M.snapshot)
requires M.contexts (pair a b) state
ensures R.pts_to a ((G.reveal state) a) ** R.pts_to b ((G.reveal state) b)
{
  rewrite M.contexts (pair a b) state as M.contexts_from (pair a b) state 0 2;
  rewrite M.contexts_from (pair a b) state 0 2 as
    (R.pts_to a ((G.reveal state) a) ** M.contexts_from (pair a b) state 1 2);
  rewrite M.contexts_from (pair a b) state 1 2 as
    (R.pts_to b ((G.reveal state) b) ** M.contexts_from (pair a b) state 2 2);
  rewrite M.contexts_from (pair a b) state 2 2 as emp;
}

fn allocate_close_reopen_preserves_other_stream ()
requires emp
ensures emp
{
  let mut bytes_a = [| 0xa5uy; 65535sz |];
  let mut bytes_b = [| 0x79uy; 65535sz |];
  let mut a = {P.sc_id = 99uL; P.sc_phase = F.Done; P.sc_buf = bytes_a};
  let mut b = {P.sc_id = 100uL; P.sc_phase = F.Processing 12ul; P.sc_buf = bytes_b};
  distinct_from_ids a b;
  let mut table = [| a; 2sz |];
  table.(1sz) <- b;
  own_pair a b;
  let mut conn = {M.cc_active = table; M.cc_num = 0ul; M.cc_capacity = 2ul};
  let absent = M.find_stream conn 4uL;
  assert (pure (absent == 0ul));
  let empty_close = M.close_stream conn 4uL;
  assert (pure (not empty_close));
  let first = M.allocate_stream conn 4uL;
  assert (pure (first == 0ul));
  let duplicate = M.allocate_stream conn 4uL;
  assert (pure (duplicate == 2ul));
  let second = M.allocate_stream conn 8uL;
  assert (pure (second == 1ul));
  let full = M.allocate_stream conn 12uL;
  assert (pure (full == 2ul));
  let missing = M.close_stream conn 123uL;
  assert (pure (not missing));
  let closed = M.close_stream conn 4uL;
  assert (pure (closed));
  let active = table.(0sz);
  let available = table.(1sz);
  assert (pure (active == b /\ available == a));
  let reopened = M.allocate_stream conn 12uL;
  assert (pure (reopened == 1ul));
  let other = M.read_slot table 0ul;
  let fresh = M.read_slot table 1ul;
  assert (pure (other.P.sc_id == 8uL /\ other.P.sc_phase == F.ReadingLength /\ other.P.sc_buf == bytes_b));
  assert (pure (fresh.P.sc_id == 12uL /\ fresh.P.sc_phase == F.ReadingLength /\ fresh.P.sc_buf == bytes_a));
  let keep_a = bytes_a.(0sz);
  let keep_b = bytes_b.(65534sz);
  assert (pure (keep_a == 0xa5uy /\ keep_b == 0x79uy));
  let close_last = M.close_stream conn 12uL;
  assert (pure (close_last));
  let again = M.close_stream conn 12uL;
  assert (pure (not again));
  release_pair a b;
  ()
}

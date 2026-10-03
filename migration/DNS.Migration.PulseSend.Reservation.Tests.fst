module DNS.Migration.PulseSend.Reservation.Tests
#lang-pulse
(* Exact interleavings of allocation, compaction and completion. *)
#set-options "--z3rlimit 100"

open Pulse.Lib.Pervasives
open Pulse.Lib.Array
module R = Pulse.Lib.Reference
module A = Pulse.Lib.Array
module S = FStar.Seq
module G = FStar.Ghost
module P = DNS.Migration.PulseStream
module M = DNS.Migration.PulseMultiplexer
module T = DNS.Migration.PulseMultiplexer.Tests
module F = DNS.QUIC.StreamModel
module E = DNS.Migration.PulseSend

(* The guarded table does not expose a writable reserved context or cursor. *)
[@@expect_failure [228]]
fn cannot_recycle_reserved_context (slot:E.send_slot) (cp:R.ref M.connection_context)
  (d:E.descriptor) (value:P.stream_context) (#saved:G.erased P.stream_context)
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires E.reserved_connection slot cp d saved c slots pool state
ensures E.reserved_connection slot cp d saved c slots pool state
{
  R.write d.E.context value;
}

[@@expect_failure [228]]
fn cannot_discard_reservation (slot:E.send_slot) (cp:R.ref M.connection_context)
  (d:E.descriptor) (#saved:G.erased P.stream_context)
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires E.reserved_connection slot cp d saved c slots pool state
ensures E.reserved_connection slot cp d saved c slots pool state
{
  slot := None;
}

fn compact_reopen_and_complete (outcome:E.outcome)
requires emp
ensures emp
{
  let mut msg_a = [| 0xa5uy; 16sz |];
  let mut msg_b = [| 0x79uy; 16sz |];
  let mut a = {P.sc_id = 0uL; P.sc_phase = F.Processing 12ul; P.sc_buf = msg_a};
  let mut b = {P.sc_id = 18446744073709551615uL; P.sc_phase = F.Processing 13ul; P.sc_buf = msg_b};
  T.distinct_from_ids a b;
  let mut table = [| a; 2sz |];
  table.(1sz) <- b;
  T.own_pair a b;
  let mut conn = {M.cc_active = table; M.cc_num = 2ul; M.cc_capacity = 2ul};
  let mut slot : option E.reservation = None;
  let mut response = [| 0x17uy; 20sz |];
  let started = E.begin_send slot conn response 14ul 18446744073709551615uL true;
  assert (pure (Some? started));
  match started {
    None -> { unreachable(); }
    Some d -> {
      assert (pure (d.E.context == b));
      let original = E.find_while_pending slot conn 18446744073709551615uL;
      assert (pure (original == 1ul));
      let blocked = E.close_other slot conn 18446744073709551615uL;
      assert (pure (not blocked));
      let full = E.allocate_while_pending slot conn 99uL;
      assert (pure (full == 2ul));
      let absent = E.close_other slot conn 77uL;
      assert (pure (not absent));
      (* Removing A swaps the reserved B from index 1 to index 0. *)
      let removed = E.close_other slot conn 0uL;
      assert (pure removed);
      let moved = E.find_while_pending slot conn 18446744073709551615uL;
      assert (pure (moved == 0ul));
      let reopened = E.allocate_while_pending slot conn 33uL;
      assert (pure (reopened == 1ul));
      let duplicate = E.allocate_while_pending slot conn 18446744073709551615uL;
      assert (pure (duplicate == 2ul));
      let view = E.inspect_pending slot conn;
      assert (pure (view == d /\ view.E.data == response /\ view.E.context == b));
      let mismatch = E.finish_send slot conn 0uL outcome;
      assert (pure (not mismatch));
      if (mismatch) { unreachable(); } else {
        (* Table operations need no response ownership, even after rejection. *)
        let closed_again = E.close_other slot conn 33uL;
        assert (pure closed_again);
        let reopened_again = E.allocate_while_pending slot conn 44uL;
        assert (pure (reopened_again == 1ul));
        let completed = E.finish_send slot conn 18446744073709551615uL outcome;
        assert (pure completed);
        if (completed) {
          with bytes. assert A.pts_to d.E.data bytes;
          rewrite A.pts_to d.E.data bytes as A.pts_to response bytes;
          let remaining = table.(0sz);
          let retired = table.(1sz);
          let current = !conn;
          assert (pure (remaining == a /\ retired == b /\ current.M.cc_num == 1ul));
          let first_byte = response.(0sz);
          let last_byte = response.(19sz);
          assert (pure (first_byte == 0x17uy /\ last_byte == 0x17uy));
          response.(0sz) <- 0xa5uy;
          with final_state. assert M.contexts (T.pair a b) final_state;
          T.release_pair a b #final_state;
          with va_before vb_before. assert R.pts_to a va_before ** R.pts_to b vb_before;
          rewrite R.pts_to a va_before as
            R.pts_to a ({P.sc_id = 44uL; P.sc_phase = F.ReadingLength; P.sc_buf = msg_a});
          rewrite R.pts_to b vb_before as
            R.pts_to b ({P.sc_id = 18446744073709551615uL; P.sc_phase = F.Processing 13ul; P.sc_buf = msg_b});
          let va = !a;
          let vb = !b;
          assert (pure (va.P.sc_id == 44uL /\ va.P.sc_phase == F.ReadingLength /\ va.P.sc_buf == msg_a /\
            vb.P.sc_id == 18446744073709551615uL /\ vb.P.sc_phase == F.Processing 13ul /\ vb.P.sc_buf == msg_b));
          let ma = msg_a.(15sz);
          let mb = msg_b.(15sz);
          assert (pure (ma == 0xa5uy /\ mb == 0x79uy));
          ()
        } else { unreachable(); }
      }
    }
  }
}

let triple (a b c:M.slot) = S.cons a (S.cons b (S.cons c S.empty))
let triple_state (a b:M.slot) (va vb vc:P.stream_context) : GTot M.snapshot =
  fun p -> if Prims.t2b (p == a) then va else if Prims.t2b (p == b) then vb else vc

ghost
fn own_triple (a b c:M.slot) (#va #vb #vc:G.erased P.stream_context)
requires R.pts_to a va ** R.pts_to b vb ** R.pts_to c vc
requires pure (a =!= b /\ a =!= c /\ b =!= c)
ensures M.contexts (triple a b c) (triple_state a b va vb vc)
{
  let pool = G.hide (triple a b c);
  let state = G.hide (triple_state a b va vb vc);
  rewrite emp as M.contexts_from pool state 3 3;
  rewrite R.pts_to c vc as R.pts_to (S.index pool 2) ((G.reveal state) (S.index pool 2));
  rewrite (R.pts_to (S.index pool 2) ((G.reveal state) (S.index pool 2)) ** M.contexts_from pool state 3 3)
    as M.contexts_from pool state 2 3;
  rewrite R.pts_to b vb as R.pts_to (S.index pool 1) ((G.reveal state) (S.index pool 1));
  rewrite (R.pts_to (S.index pool 1) ((G.reveal state) (S.index pool 1)) ** M.contexts_from pool state 2 3)
    as M.contexts_from pool state 1 3;
  rewrite R.pts_to a va as R.pts_to (S.index pool 0) ((G.reveal state) (S.index pool 0));
  rewrite (R.pts_to (S.index pool 0) ((G.reveal state) (S.index pool 0)) ** M.contexts_from pool state 1 3)
    as M.contexts_from pool state 0 3;
  rewrite M.contexts_from pool state 0 3 as M.contexts (triple a b c) (triple_state a b va vb vc);
}

ghost
fn release_triple (a b c:M.slot) (#state:G.erased M.snapshot)
requires M.contexts (triple a b c) state
ensures R.pts_to a ((G.reveal state) a) ** R.pts_to b ((G.reveal state) b) ** R.pts_to c ((G.reveal state) c)
{
  rewrite M.contexts (triple a b c) state as M.contexts_from (triple a b c) state 0 3;
  rewrite M.contexts_from (triple a b c) state 0 3 as
    (R.pts_to a ((G.reveal state) a) ** M.contexts_from (triple a b c) state 1 3);
  rewrite M.contexts_from (triple a b c) state 1 3 as
    (R.pts_to b ((G.reveal state) b) ** M.contexts_from (triple a b c) state 2 3);
  rewrite M.contexts_from (triple a b c) state 2 3 as
    (R.pts_to c ((G.reveal state) c) ** M.contexts_from (triple a b c) state 3 3);
  rewrite M.contexts_from (triple a b c) state 3 3 as emp;
}

fn duplicate_id_moved_before_reserved (outcome:E.outcome)
requires emp
ensures emp
{
  let mut ma = [| 1uy; 16sz |];
  let mut mb = [| 2uy; 16sz |];
  let mut mc = [| 3uy; 16sz |];
  let mut a = {P.sc_id = 99uL; P.sc_phase = F.Done; P.sc_buf = ma};
  let mut b = {P.sc_id = 0uL; P.sc_phase = F.Processing 12ul; P.sc_buf = mb};
  let mut c = {P.sc_id = 33uL; P.sc_phase = F.Processing 13ul; P.sc_buf = mc};
  T.distinct_from_ids a b;
  T.distinct_from_ids a c;
  T.distinct_from_ids b c;
  c := {P.sc_id = 0uL; P.sc_phase = F.Processing 13ul; P.sc_buf = mc};
  let mut table = [| a; 3sz |];
  table.(1sz) <- b;
  table.(2sz) <- c;
  own_triple a b c;
  let mut conn = {M.cc_active = table; M.cc_num = 3ul; M.cc_capacity = 3ul};
  let mut slot : option E.reservation = None;
  let mut response = [| 0xa5uy; 14sz |];
  let started = E.begin_send slot conn response 14ul 0uL true;
  assert (pure (Some? started));
  match started {
    None -> { unreachable(); }
    Some d -> {
      assert (pure (d.E.context == b));
      let closed = E.close_other slot conn 99uL;
      assert (pure closed);
      (* Table is now [c,b,a]. An ID lookup finds c, not reserved b. *)
      let first_match = E.find_while_pending slot conn 0uL;
      assert (pure (first_match == 0ul));
      let completed = E.finish_send slot conn 0uL outcome;
      assert (pure completed);
      if (completed) {
        with bytes. assert A.pts_to d.E.data bytes;
        rewrite A.pts_to d.E.data bytes as A.pts_to response bytes;
        let remaining = table.(0sz);
        let retired = table.(1sz);
        let available = table.(2sz);
        let current = !conn;
        assert (pure (remaining == c /\ retired == b /\ available == a /\ current.M.cc_num == 1ul));
        let byte = response.(13sz);
        assert (pure (byte == 0xa5uy));
        with final_state. assert M.contexts (triple a b c) final_state;
        release_triple a b c #final_state;
        with vb_before vc_before. assert R.pts_to b vb_before ** R.pts_to c vc_before;
        rewrite R.pts_to b vb_before as
          R.pts_to b ({P.sc_id = 0uL; P.sc_phase = F.Processing 12ul; P.sc_buf = mb});
        rewrite R.pts_to c vc_before as
          R.pts_to c ({P.sc_id = 0uL; P.sc_phase = F.Processing 13ul; P.sc_buf = mc});
        let vb = !b;
        let vc = !c;
        assert (pure (vb.P.sc_phase == F.Processing 12ul /\ vc.P.sc_phase == F.Processing 13ul));
        ()
      } else { unreachable(); }
    }
  }
}

fn both_outcomes ()
requires emp
ensures emp
{
  compact_reopen_and_complete E.SendCompleted;
  compact_reopen_and_complete E.SendDropped;
  duplicate_id_moved_before_reserved E.SendCompleted;
  duplicate_id_moved_before_reserved E.SendDropped;
}

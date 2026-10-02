module DNS.Migration.PulseSend.Tests
#lang-pulse
(* Chained framing and two exact close permutations, like the table regressions. *)
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
module FRAME = DNS.Migration.PulseResponse
module E = DNS.Migration.PulseSend

(* Expected Pulse resource failures, not admitted production definitions.
   These clients see only the interface: pointer values confer no write or
   table ownership. Successful checking of any bad client fails the gate. *)
[@@expect_failure [228]]
fn cannot_write_pending (slot:E.send_slot) (cp:R.ref M.connection_context)
  (d:E.descriptor) (#bytes:G.erased (S.seq FStar.UInt8.t))
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires E.pending slot cp d bytes c slots pool state
requires pure (S.length bytes > 0)
ensures E.pending slot cp d bytes c slots pool state
{
  d.E.data.(0sz) <- 0uy;
}

[@@expect_failure [228]]
fn cannot_close_pending (slot:E.send_slot) (cp:R.ref M.connection_context)
  (d:E.descriptor) (#bytes:G.erased (S.seq FStar.UInt8.t))
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires E.pending slot cp d bytes c slots pool state
ensures E.pending slot cp d bytes c slots pool state
{
  let closed = M.close_stream cp d.E.stream_id;
  ()
}

[@@expect_failure [228]]
fn cannot_begin_while_pending (slot:E.send_slot) (cp:R.ref M.connection_context)
  (d:E.descriptor) (#bytes:G.erased (S.seq FStar.UInt8.t))
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires E.pending slot cp d bytes c slots pool state
ensures E.pending slot cp d bytes c slots pool state
{
  let second = E.begin_send slot cp d.E.data d.E.length d.E.stream_id d.E.fin;
  ()
}

[@@expect_failure [228]]
fn cannot_complete_idle (slot:E.send_slot) (cp:R.ref M.connection_context)
  (response:A.array FStar.UInt8.t) (#bytes:G.erased (S.seq FStar.UInt8.t))
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires E.idle_resources slot cp response bytes c slots pool state
ensures E.idle_resources slot cp response bytes c slots pool state
{
  let duplicate = E.finish_send slot cp 0uL E.SendCompleted;
  ()
}

fn framed_send_mismatch_complete_and_reuse (outcome:E.outcome)
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
  let mut slot : option E.descriptor = None;
  let mut query = [| 0x17uy; 12sz |];
  let mut response = [| 0x79uy; 20sz |];
  let mut unrelated = 42ul;
  let length = FRAME.frame_response query response 12ul 20ul;
  assert (pure (length == 14ul));
  let missing = E.begin_send slot conn response length 99uL true;
  assert (pure (None? missing));
  match missing {
    Some _ -> { unreachable(); }
    None -> {
      let started = E.begin_send slot conn response length 0uL true;
      assert (pure (Some? started));
      match started {
        None -> { unreachable(); }
        Some d -> {
          let view = E.inspect_pending slot conn;
          assert (pure (view == d /\ view.E.stream_id == 0uL /\ view.E.data == response /\
            view.E.length == 14ul /\ view.E.fin));
          unrelated := 43ul;
          let source = query.(11sz);
          let other_message = msg_b.(15sz);
          assert (pure (source == 0x17uy /\ other_message == 0x79uy));
          let rejected = E.finish_send slot conn 18446744073709551615uL outcome;
          assert (pure (not rejected));
          if (rejected) { unreachable(); } else {
            let same = E.inspect_pending slot conn;
            assert (pure (same == d));
            let completed = E.finish_send slot conn 0uL outcome;
            assert (pure completed);
            if (completed) {
              with returned_bytes. assert A.pts_to d.E.data returned_bytes;
              rewrite A.pts_to d.E.data returned_bytes as A.pts_to response returned_bytes;
              let active = table.(0sz);
              let retired = table.(1sz);
              let current = !conn;
              let idle = !slot;
              assert (pure (active == b /\ retired == a /\ current.M.cc_num == 1ul /\ None? idle));
              let hi = response.(0sz);
              let lo = response.(1sz);
              let body = response.(13sz);
              let tail = response.(19sz);
              assert (pure (hi == 0uy /\ lo == 12uy /\ body == 0x17uy /\ tail == 0x79uy));
              (* Restored full ownership permits writes and reuse, including zero length. *)
              response.(0sz) <- 0xa5uy;
              let second = E.begin_send slot conn response 0ul 18446744073709551615uL false;
              assert (pure (Some? second));
              match second {
                None -> { unreachable(); }
                Some d2 -> {
                  let second_view = E.inspect_pending slot conn;
                  assert (pure (second_view.E.data == response /\ second_view.E.length == 0ul /\ not second_view.E.fin));
                  let stale_id = E.finish_send slot conn 0uL outcome;
                  assert (pure (not stale_id));
                  if (stale_id) { unreachable(); } else {
                    let second_done = E.finish_send slot conn 18446744073709551615uL outcome;
                    assert (pure second_done);
                    if (second_done) {
                      with reused_bytes. assert A.pts_to d2.E.data reused_bytes;
                      rewrite A.pts_to d2.E.data reused_bytes as A.pts_to response reused_bytes;
                      let empty = !conn;
                      let response_byte = response.(0sz);
                      let sentinel = !unrelated;
                      assert (pure (empty.M.cc_num == 0ul /\ response_byte == 0xa5uy /\ sentinel == 43ul));
                      T.release_pair a b;
                      let old_a = !a;
                      let old_b = !b;
                      assert (pure (old_a.P.sc_id == 0uL /\ old_a.P.sc_phase == F.Processing 12ul /\ old_a.P.sc_buf == msg_a /\
                        old_b.P.sc_id == 18446744073709551615uL /\ old_b.P.sc_phase == F.Processing 13ul /\ old_b.P.sc_buf == msg_b));
                      ()
                    } else { unreachable(); }
                  }
                }
              }
            } else { unreachable(); }
          }
        }
      }
    }
  }
}

fn both_outcomes ()
requires emp
ensures emp
{
  framed_send_mismatch_complete_and_reuse E.SendCompleted;
  framed_send_mismatch_complete_and_reuse E.SendDropped;
}

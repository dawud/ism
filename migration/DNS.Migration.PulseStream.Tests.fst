module DNS.Migration.PulseStream.Tests
#lang-pulse

open Pulse.Lib.Pervasives
open Pulse.Lib.Array
module P = DNS.Migration.PulseStream
module M = DNS.QUIC.StreamModel
module U64 = FStar.UInt64

(* These call the real imperative operations over locally owned arrays and a
   context reference. Stack syntax supplies ownership; no raw alloc assumptions. *)
fn split_prefix_bytes_and_fin ()
requires emp
ensures emp
{
  let mut message = [| 0xffuy; 65535sz |];
  let mut high = [| 0uy; 1sz |];
  let mut rest = [| 0uy; 13sz |];
  rest.(0sz) <- 12uy;
  rest.(12sz) <- 0xa5uy;
  let mut context = { P.sc_id = 7uL; P.sc_phase = M.ReadingLength; P.sc_buf = message };
  let p0 = P.handle_stream_data context high 1ul;
  assert (pure (p0 == M.ReadingLengthHigh 0uy));
  let p1 = P.handle_stream_data context rest 13ul;
  assert (pure (p1 == M.AwaitingFin 12ul));
  let id0 = message.(0sz);
  let id1 = message.(1sz);
  let last = message.(11sz);
  let untouched = message.(12sz);
  assert (pure (id0 == 0uy /\ id1 == 0uy /\ last == 0xa5uy /\ untouched == 0xffuy));
  let phase = P.handle_stream_fin context;
  assert (pure (phase == M.Processing 12ul));
  let phase_again = P.handle_stream_fin context;
  assert (pure (phase_again == M.Processing 12ul));
  let state = !context;
  assert (pure (state.P.sc_id == 7uL /\ state.P.sc_buf == message));
  ()
}

fn closed_and_invalid_states_do_not_reopen ()
requires emp
ensures emp
{
  let mut message = [| 0uy; 65535sz |];
  let mut input = [| 9uy; 1sz |];
  let mut context = { P.sc_id = 7uL; P.sc_phase = M.Done; P.sc_buf = message };
  let closed = P.handle_stream_data context input 1ul;
  assert (pure (closed == M.Done));
  let byte = message.(0sz);
  assert (pure (byte == 0uy));
  let closed_fin = P.handle_stream_fin context;
  assert (pure (closed_fin == M.Done));
  context := { P.sc_id = 7uL; P.sc_phase = M.ReadingMessage 12ul 13ul; P.sc_buf = message };
  let invalid = P.handle_stream_data context input 0ul;
  assert (pure (invalid == M.Done));
  ()
}

fn nonzero_id_and_premature_fin_rejected ()
requires emp
ensures emp
{
  let mut message = [| 0uy; 65535sz |];
  message.(1sz) <- 1uy;
  let mut context = { P.sc_id = 7uL; P.sc_phase = M.AwaitingFin 12ul; P.sc_buf = message };
  let nonzero = P.handle_stream_fin context;
  assert (pure (nonzero == M.Done));
  message.(1sz) <- 0uy;
  context := { P.sc_id = 7uL; P.sc_phase = M.ReadingMessage 12ul 11ul; P.sc_buf = message };
  let early = P.handle_stream_fin context;
  assert (pure (early == M.Done));
  ()
}

fn fragmented_body_and_rejected_copy_bounds ()
requires emp
ensures emp
{
  let mut message = [| 0xffuy; 65535sz |];
  let mut prefix = [| 0uy; 2sz |];
  prefix.(1sz) <- 12uy;
  let mut first = [| 0uy; 5sz |];
  let mut rest = [| 0xa5uy; 8sz |];
  let mut sentinel = 42ul;
  let mut context = { P.sc_id = 9uL; P.sc_phase = M.ReadingLength; P.sc_buf = message };
  let p0 = P.handle_stream_data context prefix 2ul;
  assert (pure (p0 == M.ReadingMessage 12ul 0ul));
  let p1 = P.handle_stream_data context first 5ul;
  assert (pure (p1 == M.ReadingMessage 12ul 5ul));
  (* One excess byte rejects the message but copies only the seven remaining
     declared body bytes, preserving the historical bounded-copy behavior. *)
  let p2 = P.handle_stream_data context rest 8ul;
  assert (pure (p2 == M.Done));
  let left = message.(4sz);
  let start = message.(5sz);
  let last = message.(11sz);
  let beyond = message.(12sz);
  let source = rest.(7sz);
  let unrelated = !sentinel;
  assert (pure (left == 0uy /\ start == 0xa5uy /\ last == 0xa5uy /\
    beyond == 0xffuy /\ source == 0xa5uy /\ unrelated == 42ul));
  ()
}

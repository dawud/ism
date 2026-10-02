module DNS.Migration.PulseResponse.Tests
#lang-pulse

open Pulse.Lib.Pervasives
open Pulse.Lib.Array
module P = DNS.Migration.PulseResponse
module SZ = FStar.SizeT
module T = DNS.QUIC.ResponseModel.Tests

fn empty_response_and_short_prefix_capacity ()
requires emp
ensures emp
{
  let mut input = [| 0xa5uy; 1sz |];
  let mut output = [| 0x79uy; 5sz |];
  let mut unrelated = 42ul;
  let short = P.frame_response input output 0ul 1ul;
  assert (pure (short == 0ul));
  let untouched = output.(0sz);
  assert (pure (untouched == 0x79uy));
  let framed = P.frame_response input output 0ul 2ul;
  assert (pure (framed == 2ul));
  let hi = output.(0sz);
  let lo = output.(1sz);
  let tail = output.(2sz);
  let last = output.(4sz);
  let source = input.(0sz);
  let other = !unrelated;
  assert (pure (hi == 0uy /\ lo == 0uy /\ tail == 0x79uy /\ last == 0x79uy /\
    source == 0xa5uy /\ other == 42ul));
  ()
}

fn payload_copy_and_untouched_tail ()
requires emp
ensures emp
{
  let mut input = [| 0x17uy; 17sz |];
  input.(0sz) <- 0x77uy;
  input.(11sz) <- 0xa5uy;
  let mut output = [| 0x79uy; 19sz |];
  let short = P.frame_response input output 12ul 13ul;
  assert (pure (short == 0ul));
  let unchanged = output.(2sz);
  assert (pure (unchanged == 0x79uy));
  let framed = P.frame_response input output 12ul 14ul;
  assert (pure (framed == 14ul));
  let hi = output.(0sz);
  let lo = output.(1sz);
  let first = output.(2sz);
  let middle = output.(7sz);
  let last = output.(13sz);
  let tail = output.(14sz);
  let outside_capacity = output.(18sz);
  let original = input.(11sz);
  let unused_source = input.(12sz);
  assert (pure (hi == 0uy /\ lo == 12uy /\ first == 0x77uy /\ middle == 0x17uy /\
    last == 0xa5uy /\ tail == 0x79uy /\ outside_capacity == 0x79uy /\
    original == 0xa5uy /\ unused_source == 0x17uy));
  ()
}

(* SizeT guarantees only 16 bits portably. Take actual representable lengths
   rather than adding an assumed 32-bit platform fact for these large fixtures. *)
fn maximum_payload_and_one_byte_short_destination
  (input_size:SZ.t{SZ.v input_size == 65536})
  (output_size:SZ.t{SZ.v output_size == 65539})
requires emp
ensures emp
{
  T.prefix_byte_boundaries ();
  let mut input = [| 0x17uy; input_size |];
  input.(65534sz) <- 0xa5uy;
  let mut output = [| 0x79uy; output_size |];
  let short = P.frame_response input output 65535ul 65536ul;
  assert (pure (short == 0ul));
  let untouched = output.(65535sz);
  assert (pure (untouched == 0x79uy));
  let framed = P.frame_response input output 65535ul 65537ul;
  assert (pure (framed == 65537ul));
  let hi = output.(0sz);
  let lo = output.(1sz);
  let first = output.(2sz);
  let last = output.(SZ.sub output_size 3sz);
  let tail = output.(SZ.sub output_size 2sz);
  let source = input.(65534sz);
  let unused_source = input.(65535sz);
  assert (pure (hi == 255uy /\ lo == 255uy /\ first == 0x17uy /\ last == 0xa5uy /\
    tail == 0x79uy /\ source == 0xa5uy /\ unused_source == 0x17uy));
  ()
}

fn oversized_payload_rejected_before_writes (input_size:SZ.t{SZ.v input_size == 65536})
requires emp
ensures emp
{
  let mut input = [| 0xa5uy; input_size |];
  let mut output = [| 0x79uy; 4sz |];
  let rejected = P.frame_response input output 65536ul 4ul;
  assert (pure (rejected == 0ul));
  let first = output.(0sz);
  let last = output.(3sz);
  let source = input.(65535sz);
  assert (pure (first == 0x79uy /\ last == 0x79uy /\ source == 0xa5uy));
  ()
}

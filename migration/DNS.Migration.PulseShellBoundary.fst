module DNS.Migration.PulseShellBoundary
#lang-pulse

open Pulse.Lib.Pervasives

type shell_phase =
  | MigrationReading
  | MigrationProcessing
  | MigrationClosed

noeq
type stream_state = {
  buffered: nat;
  capacity: nat;
  phase: shell_phase;
}

let available (s:stream_state) : nat =
  if s.buffered <= s.capacity then s.capacity - s.buffered else 0

let accepts_fragment (s:stream_state) (len:nat) : bool =
  len <= available s

let next_state_after_authenticated_bytes
    (s:stream_state)
    (len:nat)
  : stream_state =
  if accepts_fragment s len then
    { buffered = s.buffered + len;
      capacity = s.capacity;
      phase = MigrationProcessing }
  else
    { buffered = s.buffered;
      capacity = s.capacity;
      phase = MigrationClosed }

fn dispatch_authenticated_bytes_pilot
    (state:ref stream_state)
    (len:nat)
requires state |-> 's
returns accepted:bool
ensures exists* s1.
  state |-> s1 **
  pure (
    s1 == next_state_after_authenticated_bytes 's len /\
    accepted == accepts_fragment 's len
  )
{
  let s = !state;
  let accepted = accepts_fragment s len;
  state := next_state_after_authenticated_bytes s len;
  accepted
}

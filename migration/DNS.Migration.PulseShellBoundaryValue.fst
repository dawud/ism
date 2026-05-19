module DNS.Migration.PulseShellBoundaryValue
#lang-pulse

module U32 = FStar.UInt32

type shell_phase =
  | ValueReading
  | ValueProcessing
  | ValueClosed

noeq
type stream_state = {
  buffered: U32.t;
  capacity: U32.t;
  phase: shell_phase;
}

noeq
type dispatch_result = {
  accepted: bool;
  next: stream_state;
}

let available (s:stream_state) : U32.t =
  if U32.lte s.buffered s.capacity
  then U32.sub_mod s.capacity s.buffered
  else U32.uint_to_t 0

let accepts_fragment (s:stream_state) (len:U32.t) : bool =
  U32.lte len (available s)

let next_state_after_authenticated_bytes
    (s:stream_state)
    (len:U32.t)
  : stream_state =
  if accepts_fragment s len then
    { buffered = U32.add_mod s.buffered len;
      capacity = s.capacity;
      phase = ValueProcessing }
  else
    { buffered = s.buffered;
      capacity = s.capacity;
      phase = ValueClosed }

let dispatch_authenticated_bytes_value
    (s:stream_state)
    (len:U32.t)
  : dispatch_result =
  { accepted = accepts_fragment s len;
    next = next_state_after_authenticated_bytes s len }

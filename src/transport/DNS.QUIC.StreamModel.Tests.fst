module DNS.QUIC.StreamModel.Tests

module M = DNS.QUIC.StreamModel

(* The same regressions are checked by both pinned compilers. *)
let empty_prefix_is_idle =
  assert_norm (M.fragment_phase M.ReadingLength 0ul 99uy 99uy == M.ReadingLength)
let split_prefix =
  assert_norm (M.fragment_phase M.ReadingLength 1ul 0uy 99uy == M.ReadingLengthHigh 0uy);
  assert_norm (M.fragment_phase (M.ReadingLengthHigh 0uy) 13ul 12uy 0uy == M.AwaitingFin 12ul)
let prefix_then_fragmented_body =
  assert_norm (M.fragment_phase M.ReadingLength 2ul 0uy 12uy == M.ReadingMessage 12ul 0ul);
  assert_norm (M.fragment_phase (M.ReadingMessage 12ul 0ul) 5ul 0uy 0uy == M.ReadingMessage 12ul 5ul);
  assert_norm (M.fragment_phase (M.ReadingMessage 12ul 5ul) 7ul 0uy 0uy == M.AwaitingFin 12ul)
let complete_body_is_not_processing =
  assert_norm (M.fragment_phase M.ReadingLength 14ul 0uy 12uy == M.AwaitingFin 12ul)
let exact_fin_and_repeat =
  assert_norm (M.finish_doq_phase (M.AwaitingFin 12ul) 0uy 0uy == M.Processing 12ul);
  assert_norm (M.finish_doq_phase (M.Processing 12ul) 0uy 0uy == M.Processing 12ul)
let premature_fin =
  assert_norm (M.finish_doq_phase M.ReadingLength 0uy 0uy == M.Done);
  assert_norm (M.finish_doq_phase (M.ReadingLengthHigh 0uy) 0uy 0uy == M.Done);
  assert_norm (M.finish_doq_phase (M.ReadingMessage 12ul 11ul) 0uy 0uy == M.Done)
let nonzero_id =
  assert_norm (M.finish_doq_phase (M.AwaitingFin 12ul) 1uy 0uy == M.Done);
  assert_norm (M.finish_doq_phase (M.AwaitingFin 12ul) 0uy 1uy == M.Done)
let short_or_zero_length =
  assert_norm (M.fragment_phase M.ReadingLength 2ul 0uy 0uy == M.Done);
  assert_norm (M.fragment_phase M.ReadingLength 2ul 0uy 11uy == M.Done)
let excess_bytes =
  assert_norm (M.fragment_phase M.ReadingLength 15ul 0uy 12uy == M.Done);
  assert_norm (M.fragment_phase (M.ReadingMessage 12ul 5ul) 8ul 0uy 0uy == M.Done);
  assert_norm (M.fragment_phase (M.AwaitingFin 12ul) 1ul 0uy 0uy == M.Done);
  assert_norm (M.fragment_phase (M.Processing 12ul) 1ul 0uy 0uy == M.Done)
let closed_never_reopens =
  assert_norm (M.fragment_phase M.Done 0ul 0uy 0uy == M.Done);
  assert_norm (M.fragment_phase M.Done 1ul 0uy 0uy == M.Done);
  assert_norm (M.finish_doq_phase M.Done 0uy 0uy == M.Done)
let invalid_body_states =
  assert_norm (not (M.valid_phase (M.ReadingMessage 12ul 13ul)));
  assert_norm (M.fragment_phase (M.ReadingMessage 12ul 13ul) 0ul 0uy 0uy == M.Done);
  assert_norm (M.fragment_phase (M.ReadingMessage 11ul 0ul) 0ul 0uy 0uy == M.Done)
let size_limit_and_overflow =
  assert_norm (M.fragment_phase M.ReadingLength 65537ul 255uy 255uy == M.AwaitingFin 65535ul);
  assert_norm (M.fragment_phase M.ReadingLength 65538ul 255uy 255uy == M.Done);
  assert_norm (M.fragment_phase (M.ReadingMessage 65535ul 65534ul) 0xfffffffful 0uy 0uy == M.Done)
let copy_ranges =
  assert_norm (M.fragment_copy_plan M.ReadingLength 15ul 0uy 12uy ==
    { M.source_offset = 2ul; M.destination_offset = 0ul; M.count = 12ul });
  assert_norm (M.fragment_copy_plan (M.ReadingLengthHigh 0uy) 6ul 12uy 0uy ==
    { M.source_offset = 1ul; M.destination_offset = 0ul; M.count = 5ul });
  assert_norm (M.fragment_copy_plan (M.ReadingMessage 12ul 5ul) 7ul 0uy 0uy ==
    { M.source_offset = 0ul; M.destination_offset = 5ul; M.count = 7ul });
  assert_norm ((M.fragment_copy_plan M.Done 1ul 0uy 0uy).M.count == 0ul)

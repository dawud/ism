module DNS.QUIC.StreamModel

(* Shared, heap-independent semantics for the stable Low* and candidate Pulse
   implementations. No transport authentication or concurrency is modeled. *)
module U8 = FStar.UInt8
module U32 = FStar.UInt32
module CAST = FStar.Int.Cast
module S = FStar.Seq

(* Keep this tag order distinct from the stable StreamMapping datatype:
   pinned KaRaMeL hash-conses identical constructor-name lists across modules,
   otherwise replacing the shell's public StreamMapping_* enum names with
   StreamModel_* names. The proved conversions, never raw tag casts, relate
   the two representations. *)
type stream_phase =
  | Done
  | ReadingLength
  | ReadingLengthHigh of (hi:U8.t)
  | ReadingMessage : expected:U32.t{U32.v expected <= 65535} -> current:U32.t -> stream_phase
  | AwaitingFin of (expected:U32.t{U32.v expected <= 65535})
  | Processing of (expected:U32.t{U32.v expected <= 65535})

let valid_phase (phase:stream_phase) : bool =
  match phase with
  | ReadingMessage expected current ->
      12 <= U32.v expected && U32.v current < U32.v expected
  | AwaitingFin expected | Processing expected -> 12 <= U32.v expected
  | _ -> true

let u32_from_be_u16_bytes (hi lo:U8.t)
  : Tot (n:U32.t{U32.v n <= 65535}) =
  let hi32 = CAST.uint8_to_uint32 hi in
  let lo32 = CAST.uint8_to_uint32 lo in
  assert (U32.v hi32 < 256);
  assert (U32.v lo32 < 256);
  let shifted = U32.shift_left hi32 8ul in
  assert (U32.v shifted <= 65280);
  assert (U32.v shifted + U32.v lo32 <= 65535);
  U32.add shifted lo32

let body_bytes_after_prefix (len:U32.t) : Tot U32.t =
  if U32.gte len 2ul then U32.sub len 2ul else 0ul

let body_bytes_after_stored_prefix (len:U32.t) : Tot U32.t =
  if U32.gte len 1ul then U32.sub len 1ul else 0ul

let advance_message (expected:U32.t{U32.v expected <= 65535})
  (current:U32.t) (incoming:U32.t{U32.v current + U32.v incoming < 4294967296})
  : Tot stream_phase =
  let total_len = U32.add current incoming in
  if U32.gte total_len expected then AwaitingFin expected
  else ReadingMessage expected total_len

let remaining_message (expected:U32.t{U32.v expected <= 65535}) (current:U32.t)
  : Tot U32.t =
  if U32.gte current expected then 0ul else U32.sub expected current

let advance_message_checked (expected:U32.t{U32.v expected <= 65535})
  (current incoming:U32.t) : Tot stream_phase =
  let remaining = remaining_message expected current in
  if U32.lt expected 12ul || U32.gt current expected || U32.gt incoming remaining
  then Done
  else advance_message expected current incoming

let advance_body_phase (phase:stream_phase) (incoming:U32.t) : Tot stream_phase =
  match phase with
  | ReadingMessage expected current -> advance_message_checked expected current incoming
  | AwaitingFin _ | Processing _ -> if U32.gt incoming 0ul then Done else phase
  | _ -> Done

let lemma_body_fragmentation
  (expected:U32.t{12 <= U32.v expected /\ U32.v expected <= 65535})
  (current:U32.t{U32.v current < U32.v expected})
  (a:U32.t) (b:U32.t{U32.v a + U32.v b < 4294967296})
  : Lemma (advance_body_phase (advance_message_checked expected current a) b ==
           advance_message_checked expected current (U32.add a b)) = ()

let fragment_phase (phase:stream_phase) (len:U32.t) (first second:U8.t)
  : Tot stream_phase =
  match phase with
  | ReadingLengthHigh hi ->
      if U32.gte len 1ul then
        advance_message_checked (u32_from_be_u16_bytes hi first) 0ul
          (body_bytes_after_stored_prefix len)
      else phase
  | ReadingLength ->
      if U32.gte len 2ul then
        advance_message_checked (u32_from_be_u16_bytes first second) 0ul
          (body_bytes_after_prefix len)
      else if U32.eq len 1ul then ReadingLengthHigh first else phase
  | _ -> advance_body_phase phase len

let finish_stream_phase (phase:stream_phase) : Tot stream_phase =
  match phase with
  | AwaitingFin expected -> Processing expected
  | Processing _ -> phase
  | _ -> Done

let lemma_fin_requires_complete_message (phase:stream_phase)
  : Lemma (match finish_stream_phase phase with
           | Processing n -> phase == AwaitingFin n \/ phase == Processing n
           | _ -> True) = ()

let finish_doq_phase (phase:stream_phase) (id_hi id_lo:U8.t) : Tot stream_phase =
  if U8.eq id_hi 0uy && U8.eq id_lo 0uy then finish_stream_phase phase else Done

let lemma_fragment_preserves_valid_phase
  (phase:stream_phase{valid_phase phase}) (len:U32.t) (first second:U8.t)
  : Lemma (valid_phase (fragment_phase phase len first second)) = ()

let lemma_fin_preserves_valid_phase
  (phase:stream_phase{valid_phase phase}) (hi lo:U8.t)
  : Lemma (valid_phase (finish_doq_phase phase hi lo)) = ()

let lemma_done_is_terminal (len:U32.t) (first second:U8.t)
  : Lemma (fragment_phase Done len first second == Done /\
           finish_doq_phase Done first second == Done) = ()

let bounded_copy_len (available wanted:U32.t) : Tot U32.t =
  if U32.lt available wanted then available else wanted

type copy_plan = { source_offset: U32.t; destination_offset: U32.t; count: U32.t }

(* Match stable copying even for rejected input: a bounded prefix may be copied
   before its phase becomes Done. Only bytes in this range may change. *)
let fragment_copy_plan (phase:stream_phase) (len:U32.t) (first second:U8.t)
  : Tot (p:copy_plan{
      U32.v p.source_offset + U32.v p.count <= U32.v len /\
      U32.v p.destination_offset + U32.v p.count <= 65535}) =
  let empty = { source_offset = 0ul; destination_offset = 0ul; count = 0ul } in
  match phase with
  | ReadingLengthHigh hi ->
      if U32.gte len 1ul then
        let expected = u32_from_be_u16_bytes hi first in
        { source_offset = 1ul; destination_offset = 0ul;
          count = bounded_copy_len (body_bytes_after_stored_prefix len) expected }
      else empty
  | ReadingLength ->
      if U32.gte len 2ul then
        let expected = u32_from_be_u16_bytes first second in
        { source_offset = 2ul; destination_offset = 0ul;
          count = bounded_copy_len (body_bytes_after_prefix len) expected }
      else empty
  | ReadingMessage expected current ->
      if U32.lt current expected then
        { source_offset = 0ul; destination_offset = current;
          count = bounded_copy_len len (remaining_message expected current) }
      else empty
  | _ -> empty

(* Byte-level footprint shared by the buffer implementations. *)
noextract
let copied_bytes (before input after:FStar.Seq.seq U8.t)
  (source destination count:nat) =
  source + count <= FStar.Seq.length input /\
  destination + count <= FStar.Seq.length before /\
  FStar.Seq.length after == FStar.Seq.length before /\
  (forall (i:nat). i < FStar.Seq.length after ==>
    FStar.Seq.index after i ==
      (if destination <= i && i < destination + count
       then FStar.Seq.index input (source + i - destination)
       else FStar.Seq.index before i))

let lemma_copied_bytes_from_slices (before input after:FStar.Seq.seq U8.t)
  (source destination count:nat{
    source + count <= FStar.Seq.length input /\
    destination + count <= FStar.Seq.length before /\
    FStar.Seq.length after == FStar.Seq.length before})
  : Lemma
    (requires (
      FStar.Seq.slice after destination (destination + count) ==
        FStar.Seq.slice input source (source + count) /\
      FStar.Seq.slice after 0 destination == FStar.Seq.slice before 0 destination /\
      FStar.Seq.slice after (destination + count) (FStar.Seq.length after) ==
        FStar.Seq.slice before (destination + count) (FStar.Seq.length before)))
    (ensures (copied_bytes before input after source destination count)) =
  let at_index (i:nat)
    : Lemma (i < S.length after ==>
      S.index after i ==
        (if destination <= i && i < destination + count
         then S.index input (source + i - destination) else S.index before i)) =
    if i < S.length after then
      if destination <= i && i < destination + count then (
        S.lemma_index_slice after destination (destination + count) (i - destination);
        S.lemma_index_slice input source (source + count) (i - destination)
      ) else if i < destination then (
        S.lemma_index_slice after 0 destination i;
        S.lemma_index_slice before 0 destination i
      ) else (
        S.lemma_index_slice after (destination + count) (S.length after) (i - (destination + count));
        S.lemma_index_slice before (destination + count) (S.length before) (i - (destination + count))
      )
    else () in
  FStar.Classical.forall_intro at_index

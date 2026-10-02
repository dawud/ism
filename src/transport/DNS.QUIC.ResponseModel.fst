module DNS.QUIC.ResponseModel

(* Shared framing semantics only: no DNS response construction, send event,
   completion token, authentication or asynchronous buffer lifetime is modeled. *)
module U8 = FStar.UInt8
module U32 = FStar.UInt32
module CAST = FStar.Int.Cast
module S = FStar.Seq
module STREAM = DNS.QUIC.StreamModel

let framed_length (length capacity:U32.t)
  : Tot (result:U32.t{
      (U32.v result = 0 <==> U32.v length > 65535 \/ U32.v capacity < U32.v length + 2) /\
      (U32.v result <> 0 ==> U32.v result == U32.v length + 2 /\ U32.v result <= U32.v capacity)}) =
  if U32.gt length 65535ul then 0ul else
  let framed = U32.add length 2ul in
  if U32.lt capacity framed then 0ul else framed

let prefix_hi (length:U32.t) : U8.t =
  CAST.uint32_to_uint8 (U32.shift_right length 8ul)

let prefix_lo (length:U32.t) : U8.t = CAST.uint32_to_uint8 length

let lemma_prefix_roundtrip (length:U32.t{U32.v length <= 65535})
  : Lemma (STREAM.u32_from_be_u16_bytes (prefix_hi length) (prefix_lo length) == length) = ()

noextract
let framed_bytes (before input after:S.seq U8.t) (length:U32.t) : prop =
  U32.v length <= 65535 /\ U32.v length <= S.length input /\
  U32.v length + 2 <= S.length before /\ S.length after == S.length before /\
  (forall (i:nat). i < S.length after ==>
    S.index after i ==
      (if i = 0 then prefix_hi length else
       if i = 1 then prefix_lo length else
       if i < U32.v length + 2 then S.index input (i - 2) else S.index before i))

noextract
let framing_result (before input after:S.seq U8.t) (length capacity result:U32.t) : prop =
  result == framed_length length capacity /\
  (if U32.v result = 0 then after == before else framed_bytes before input after length)

let lemma_frame_from_copy (before input prefixed after:S.seq U8.t)
  (length:U32.t{U32.v length <= 65535 /\ U32.v length <= S.length input /\
    U32.v length + 2 <= S.length before})
  : Lemma
    (requires (
      prefixed == S.upd (S.upd before 0 (prefix_hi length)) 1 (prefix_lo length) /\
      STREAM.copied_bytes prefixed input after 0 2 (U32.v length)))
    (ensures (framed_bytes before input after length)) = ()

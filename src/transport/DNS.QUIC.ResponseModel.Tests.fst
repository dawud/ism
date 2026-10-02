module DNS.QUIC.ResponseModel.Tests

module R = DNS.QUIC.ResponseModel

let zero_length_still_has_prefix () : Lemma (
  R.framed_length 0ul 2ul == 2ul /\ R.prefix_hi 0ul == 0uy /\ R.prefix_lo 0ul == 0uy) = ()

let capacity_and_protocol_bounds () : Lemma (
  R.framed_length 0ul 1ul == 0ul /\
  R.framed_length 12ul 13ul == 0ul /\ R.framed_length 12ul 14ul == 14ul /\
  R.framed_length 65535ul 65536ul == 0ul /\ R.framed_length 65535ul 65537ul == 65537ul /\
  R.framed_length 65536ul 4294967295ul == 0ul /\
  R.framed_length 4294967295ul 4294967295ul == 0ul) = ()

let prefix_byte_boundaries () : Lemma (
  R.prefix_hi 255ul == 0uy /\ R.prefix_lo 255ul == 255uy /\
  R.prefix_hi 256ul == 1uy /\ R.prefix_lo 256ul == 0uy /\
  R.prefix_hi 65535ul == 255uy /\ R.prefix_lo 65535ul == 255uy) = ()

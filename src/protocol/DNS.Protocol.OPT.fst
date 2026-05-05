module DNS.Protocol.OPT

open FStar.UInt16
open FStar.UInt8
open FStar.Bytes

(* OPT-specific flags (e.g., DNSSEC OK bit) *)
type opt_flags = {
  do_bit: bool;
  z: n:FStar.UInt16.t{FStar.UInt16.v n < 32768}; (* Reserved, must be 0 *)
}

(* Individual EDNS Option (e.g., Cookie, ECS, EDE) *)
type edns_option = {
  code: FStar.UInt16.t;
  len:  FStar.UInt16.t;
  data: b:bytes{length b == FStar.UInt16.v len};
}

(* The OPT Pseudo-RR definition *)
type opt_record = {
  udp_payload_size: FStar.UInt16.t;
  ext_rcode: FStar.UInt8.t;
  version:   v:FStar.UInt8.t{FStar.UInt8.v v == 0}; (* We only support Version 0 *)
  flags:     opt_flags;
  options:   list edns_option;
}

(* --- Security Padding Logic (RFC 7830 / 9250) --- *)

(* Clamp the payload size to prevent resource exhaustion attacks *)
let safe_payload_size (requested: FStar.UInt16.t) : FStar.UInt16.t =
  if FStar.UInt16.v requested > 4096 then 4096us else requested

(* Generate verified padding to reach a specific block size *)
val calculate_padding_len : current_len:FStar.UInt32.t -> block_size:FStar.UInt32.t -> Tot FStar.UInt32.t
let calculate_padding_len current_len block_size =
  if FStar.UInt32.v block_size = 0 then 0ul
  else
    let remainder = FStar.UInt32.v current_len % FStar.UInt32.v block_size in
    if remainder = 0 then 0ul else FStar.UInt32.uint_to_t (FStar.UInt32.v block_size - remainder)

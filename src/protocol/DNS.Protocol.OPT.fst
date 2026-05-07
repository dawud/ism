module DNS.Protocol.OPT

open FStar.UInt16
open FStar.UInt8
open FStar.Bytes
module L = FStar.List.Tot
module LPP = FStar.List.Pure.Properties

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

let padding_option_code : FStar.UInt16.t = 12us

let u16_from_be (hi:FStar.UInt8.t) (lo:FStar.UInt8.t) : FStar.UInt16.t =
  FStar.UInt16.uint_to_t (Prims.op_Addition (Prims.op_Multiply (FStar.UInt8.v hi) 256) (FStar.UInt8.v lo))

let u16_hi (n:FStar.UInt16.t) : FStar.UInt8.t =
  FStar.UInt8.uint_to_t (FStar.UInt16.v n / 256)

let u16_lo (n:FStar.UInt16.t) : FStar.UInt8.t =
  FStar.UInt8.uint_to_t (FStar.UInt16.v n % 256)

val bytes_to_list_from :
  fuel:nat ->
  offset:nat ->
  b:bytes{offset + fuel <= length b} ->
  Tot (list FStar.UInt8.t) (decreases fuel)

let rec bytes_to_list_from fuel offset b =
  if fuel = 0 then
    []
  else
    index b offset :: bytes_to_list_from (fuel - 1) (offset + 1) b

let bytes_to_list (b:bytes) : list FStar.UInt8.t =
  bytes_to_list_from (length b) 0 b

val repeat_byte :
  n:nat ->
  b:FStar.UInt8.t ->
  Tot (list FStar.UInt8.t) (decreases n)

let rec repeat_byte n b =
  if n = 0 then [] else b :: repeat_byte (n - 1) b

let serialize_edns_option_bytes (opt:edns_option) : list FStar.UInt8.t =
  L.append [
    u16_hi opt.code; u16_lo opt.code;
    u16_hi opt.len; u16_lo opt.len
  ] (bytes_to_list opt.data)

val serialize_edns_options_bytes :
  options:list edns_option ->
  Tot (list FStar.UInt8.t)

let rec serialize_edns_options_bytes options =
  match options with
  | [] -> []
  | opt :: rest ->
      L.append
        (serialize_edns_option_bytes opt)
        (serialize_edns_options_bytes rest)

let serialize_padding_option_bytes (padding_len:FStar.UInt16.t) : list FStar.UInt8.t =
  L.append [
    u16_hi padding_option_code; u16_lo padding_option_code;
    u16_hi padding_len; u16_lo padding_len
  ] (repeat_byte (FStar.UInt16.v padding_len) 0uy)

let opt_flags_to_u16 (flags:opt_flags) : FStar.UInt16.t =
  let z = FStar.UInt16.v flags.z in
  if flags.do_bit then
    FStar.UInt16.uint_to_t (32768 + z)
  else
    flags.z

val serialize_opt_rr_bytes_with_payload :
  udp_payload_size:FStar.UInt16.t ->
  ext_rcode:FStar.UInt8.t ->
  version:FStar.UInt8.t ->
  flags:opt_flags ->
  option_payload:list FStar.UInt8.t ->
  Tot (option (list FStar.UInt8.t))

let serialize_opt_rr_bytes_with_payload udp_payload_size ext_rcode version flags option_payload =
  let rdlen = L.length option_payload in
  if rdlen > 65535 then
    None
  else
    let rdlen_u16 = FStar.UInt16.uint_to_t rdlen in
    let flag_bits = opt_flags_to_u16 flags in
    Some (L.append [
      0uy;
      0x00uy; 0x29uy;
      u16_hi udp_payload_size; u16_lo udp_payload_size;
      ext_rcode; version; u16_hi flag_bits; u16_lo flag_bits;
      u16_hi rdlen_u16; u16_lo rdlen_u16
    ] option_payload)

let serialize_opt_rr_bytes (opt:opt_record) : option (list FStar.UInt8.t) =
  serialize_opt_rr_bytes_with_payload
    opt.udp_payload_size
    opt.ext_rcode
    opt.version
    opt.flags
    (serialize_edns_options_bytes opt.options)

val parse_option_data_bytes :
  len:FStar.UInt16.t ->
  input:list FStar.UInt8.t ->
  Tot (option (bytes * list FStar.UInt8.t))

let parse_option_data_bytes len input =
  let n = FStar.UInt16.v len in
  if L.length input < n then
    None
  else
    let (data, tail) = L.splitAt n input in
    LPP.splitAt_length n input;
    assert (L.length data == n);
    let n32 = FStar.UInt32.uint_to_t n in
    assert (FStar.UInt32.v n32 == n);
    Some (FStar.Bytes.init n32 (fun i -> L.index data (FStar.UInt32.v i)), tail)

val parse_edns_option_bytes :
  input:list FStar.UInt8.t ->
  Tot (option (edns_option * list FStar.UInt8.t))

let parse_edns_option_bytes input =
  if L.length input < 4 then
    None
  else
    match input with
    | code_hi :: code_lo :: len_hi :: len_lo :: option_data ->
        let code = u16_from_be code_hi code_lo in
        let len = u16_from_be len_hi len_lo in
        match parse_option_data_bytes len option_data with
        | None -> None
        | Some (data, tail) ->
            Some ({ code = code; len = len; data = data }, tail)
    | _ -> None

val parse_edns_options_bytes :
  fuel:nat ->
  input:list FStar.UInt8.t ->
  Tot (option (list edns_option)) (decreases fuel)

let rec parse_edns_options_bytes fuel input =
  match input with
  | [] -> Some []
  | _ ->
      if fuel = 0 then
        None
      else
        match parse_edns_option_bytes input with
        | None -> None
        | Some (opt, rest) ->
            match parse_edns_options_bytes (fuel - 1) rest with
            | None -> None
            | Some opts -> Some (opt :: opts)

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

val serialize_padding_option_for_block :
  current_len:FStar.UInt32.t ->
  block_size:FStar.UInt32.t ->
  Tot (option (list FStar.UInt8.t))

let serialize_padding_option_for_block current_len block_size =
  if FStar.UInt32.v block_size = 0 then
    Some []
  else if FStar.UInt32.v current_len > 4294967291 then
    None
  else
    let padded_base = FStar.UInt32.uint_to_t (FStar.UInt32.v current_len + 4) in
    let padding_len = calculate_padding_len padded_base block_size in
    if FStar.UInt32.v padding_len > 65535 then
      None
    else
      Some (serialize_padding_option_bytes (FStar.UInt16.uint_to_t (FStar.UInt32.v padding_len)))

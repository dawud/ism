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

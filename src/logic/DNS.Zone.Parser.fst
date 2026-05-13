module DNS.Zone.Parser

open FStar.Bytes
open DNS.Name
open DNS.Protocol
open DNS.RCode
module C = DNS.Constants
module L = FStar.List.Tot
module OPT = DNS.Protocol.OPT

(* A Zone Entry represents a single line/record in a master file *)
type zone_entry = {
  ze_origin: qname;
  ze_ttl:    FStar.UInt32.t;
  ze_class:  FStar.UInt16.t;
  ze_rtype:  qtype;
  ze_rdata:  FStar.Bytes.bytes; 
}

(* We use EverParse to generate a validator that checks the consistency 
   of the RDATA against the RTYPE (e.g., an A record must be exactly 4 bytes) *)
val validate_zone_entry : entry:zone_entry -> Tot bool
let validate_zone_entry e =
  match e.ze_rtype with
  | A          -> FStar.Bytes.length e.ze_rdata = 4
  | AAAA       -> FStar.Bytes.length e.ze_rdata = 16
  | _          -> true (* Further refinements for each type to be added *)

val valid_zone_rdata_length :
  rtype:qtype ->
  rdlen:FStar.UInt16.t ->
  Tot bool

let valid_zone_rdata_length rtype rdlen =
  match rtype with
  | A -> rdlen = 4us
  | AAAA -> rdlen = 16us
  | _ -> true

let u16_from_be (hi:FStar.UInt8.t) (lo:FStar.UInt8.t) : FStar.UInt16.t =
  FStar.UInt16.uint_to_t (Prims.op_Addition (Prims.op_Multiply (FStar.UInt8.v hi) 256) (FStar.UInt8.v lo))

let u32_from_be (b0:FStar.UInt8.t) (b1:FStar.UInt8.t) (b2:FStar.UInt8.t) (b3:FStar.UInt8.t) : FStar.UInt32.t =
  FStar.UInt32.uint_to_t (
    Prims.op_Addition
      (Prims.op_Multiply (FStar.UInt8.v b0) 16777216)
      (Prims.op_Addition
        (Prims.op_Multiply (FStar.UInt8.v b1) 65536)
        (Prims.op_Addition
          (Prims.op_Multiply (FStar.UInt8.v b2) 256)
          (FStar.UInt8.v b3))))

val bytes_of_list :
  input:list FStar.UInt8.t ->
  Tot FStar.Bytes.bytes

let bytes_of_list input =
  let len = L.length input in
  if len <= 4294967295 then
    let len32 = FStar.UInt32.uint_to_t len in
    assert (FStar.UInt32.v len32 == len);
    FStar.Bytes.init len32 (fun i -> L.index input (FStar.UInt32.v i))
  else
    FStar.Bytes.empty_bytes

val parse_zone_entry_bytes :
  input:list FStar.UInt8.t ->
  Tot (option zone_entry)

let parse_zone_entry_bytes input =
  match parse_qname 128 input with
  | None -> None
  | Some (origin, rest) ->
      if L.length rest < 10 then
        None
      else
        match rest with
        | ttl_0 :: ttl_1 :: ttl_2 :: ttl_3 ::
          class_hi :: class_lo ::
          type_hi :: type_lo ::
          rdlen_hi :: rdlen_lo ::
          rdata_input ->
            let rdlen = u16_from_be rdlen_hi rdlen_lo in
            let rtype = C.u16_to_qtype (u16_from_be type_hi type_lo) in
            let len = FStar.UInt16.v rdlen in
            if L.length rdata_input <> len then
              None
            else if not (valid_zone_rdata_length rtype rdlen) then
              None
            else
              let entry = {
                ze_origin = origin;
                ze_ttl = u32_from_be ttl_0 ttl_1 ttl_2 ttl_3;
                ze_class = u16_from_be class_hi class_lo;
                ze_rtype = rtype;
                ze_rdata = bytes_of_list rdata_input;
              } in
              Some entry
        | _ -> None

(* Bootstrap parser for one bounded binary zone entry:
   origin qname, TTL, CLASS, TYPE, RDLENGTH, and exact RDATA bytes. *)
val parse_zone_file : input:FStar.Bytes.bytes -> Tot (option (list zone_entry))
let parse_zone_file input =
  match parse_zone_entry_bytes (OPT.bytes_to_list input) with
  | Some entry -> Some [entry]
  | None -> None

let valid_a_zone_entry_bytes : list FStar.UInt8.t = [
    0x03uy; 0x77uy; 0x77uy; 0x77uy;
    0x07uy; 0x65uy; 0x78uy; 0x61uy; 0x6duy; 0x70uy; 0x6cuy; 0x65uy;
    0x03uy; 0x63uy; 0x6fuy; 0x6duy;
    0x00uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x04uy;
    0x01uy; 0x02uy; 0x03uy; 0x04uy
  ]

let valid_a_zone_file_parse_test =
  assert_norm (
    match parse_zone_entry_bytes valid_a_zone_entry_bytes with
    | Some entry ->
        L.length entry.ze_origin == 3 /\
        entry.ze_ttl == 60ul /\
        entry.ze_class == 1us /\
        entry.ze_rtype == A
    | None -> false)

let invalid_a_rdata_zone_entry_bytes : list FStar.UInt8.t = [
    0x03uy; 0x77uy; 0x77uy; 0x77uy;
    0x07uy; 0x65uy; 0x78uy; 0x61uy; 0x6duy; 0x70uy; 0x6cuy; 0x65uy;
    0x03uy; 0x63uy; 0x6fuy; 0x6duy;
    0x00uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x02uy;
    0x01uy; 0x02uy
  ]

let invalid_a_rdata_zone_file_rejected_test =
  assert_norm (parse_zone_entry_bytes invalid_a_rdata_zone_entry_bytes == None)

let valid_aaaa_zone_entry_bytes : list FStar.UInt8.t = [
    0x03uy; 0x77uy; 0x77uy; 0x77uy;
    0x07uy; 0x65uy; 0x78uy; 0x61uy; 0x6duy; 0x70uy; 0x6cuy; 0x65uy;
    0x03uy; 0x63uy; 0x6fuy; 0x6duy;
    0x00uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x01uy;
    0x00uy; 0x1cuy;
    0x00uy; 0x10uy;
    0x20uy; 0x01uy; 0x0duy; 0xb8uy;
    0x00uy; 0x00uy; 0x00uy; 0x00uy;
    0x00uy; 0x00uy; 0x00uy; 0x00uy;
    0x00uy; 0x00uy; 0x00uy; 0x01uy
  ]

let valid_aaaa_zone_file_parse_test =
  assert_norm (
    match parse_zone_entry_bytes valid_aaaa_zone_entry_bytes with
    | Some entry ->
        entry.ze_rtype == AAAA
    | None -> false)

let truncated_zone_entry_bytes : list FStar.UInt8.t = [
    0x03uy; 0x77uy; 0x77uy; 0x77uy;
    0x07uy; 0x65uy; 0x78uy; 0x61uy; 0x6duy; 0x70uy; 0x6cuy; 0x65uy;
    0x03uy; 0x63uy; 0x6fuy; 0x6duy;
    0x00uy;
    0x00uy; 0x00uy
  ]

let truncated_zone_file_rejected_test =
  assert_norm (parse_zone_entry_bytes truncated_zone_entry_bytes == None)

let trailing_zone_entry_bytes : list FStar.UInt8.t = [
    0x03uy; 0x77uy; 0x77uy; 0x77uy;
    0x07uy; 0x65uy; 0x78uy; 0x61uy; 0x6duy; 0x70uy; 0x6cuy; 0x65uy;
    0x03uy; 0x63uy; 0x6fuy; 0x6duy;
    0x00uy;
    0x00uy; 0x00uy; 0x00uy; 0x3cuy;
    0x00uy; 0x01uy;
    0x00uy; 0x01uy;
    0x00uy; 0x04uy;
    0x01uy; 0x02uy; 0x03uy; 0x04uy;
    0xffuy
  ]

let trailing_zone_file_rejected_test =
  assert_norm (parse_zone_entry_bytes trailing_zone_entry_bytes == None)

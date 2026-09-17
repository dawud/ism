module DNS.Protocol.Serializer

open DNS.Protocol
open DNS.Constants
module L = FStar.List.Tot
module N = DNS.Name
module OPT = DNS.Protocol.OPT
module R = DNS.RCode
module P = DNS.Protocol.Parser

let u16_hi (n:FStar.UInt16.t) : FStar.UInt8.t =
  FStar.UInt8.uint_to_t (FStar.UInt16.v n / 256)

let u16_lo (n:FStar.UInt16.t) : FStar.UInt8.t =
  FStar.UInt8.uint_to_t (FStar.UInt16.v n % 256)

let u32_b0 (n:FStar.UInt32.t) : FStar.UInt8.t =
  FStar.UInt8.uint_to_t ((FStar.UInt32.v n / 16777216) % 256)

let u32_b1 (n:FStar.UInt32.t) : FStar.UInt8.t =
  FStar.UInt8.uint_to_t ((FStar.UInt32.v n / 65536) % 256)

let u32_b2 (n:FStar.UInt32.t) : FStar.UInt8.t =
  FStar.UInt8.uint_to_t ((FStar.UInt32.v n / 256) % 256)

let u32_b3 (n:FStar.UInt32.t) : FStar.UInt8.t =
  FStar.UInt8.uint_to_t (FStar.UInt32.v n % 256)

let flags_to_u16 (flags:dns_flags) : FStar.UInt16.t =
  FStar.UInt16.uint_to_t (
    (if flags.qr then 32768 else 0) +
    (Prims.op_Multiply (FStar.UInt16.v flags.opcode) 2048) +
    (if flags.aa then 1024 else 0) +
    (if flags.tc then 512 else 0) +
    (if flags.rd then 256 else 0) +
    (if flags.ra then 128 else 0) +
    (if flags.z then 64 else 0) +
    (if flags.ad then 32 else 0) +
    (if flags.cd then 16 else 0) +
    FStar.UInt16.v flags.rcode)

let serialize_header_bytes (h:header) : list FStar.UInt8.t =
  let flags = flags_to_u16 h.flags in
  [
    u16_hi h.id; u16_lo h.id;
    u16_hi flags; u16_lo flags;
    u16_hi h.qdcount; u16_lo h.qdcount;
    u16_hi h.ancount; u16_lo h.ancount;
    u16_hi h.nscount; u16_lo h.nscount;
    u16_hi h.arcount; u16_lo h.arcount
  ]

let rec serialize_qname_labels (name:N.qname) : list FStar.UInt8.t =
  match name with
  | [] -> [0uy]
  | label :: rest ->
      L.append
        (FStar.UInt8.uint_to_t (L.length label) :: label)
        (serialize_qname_labels rest)

let serialize_qname_uncompressed (name:N.qname) : option (list FStar.UInt8.t) =
  if N.dns_name_length name > 255 then
    None
  else
    Some (serialize_qname_labels name)

let serialize_question_bytes (q:question) : option (list FStar.UInt8.t) =
  match serialize_qname_uncompressed q.qname with
  | None -> None
  | Some qname_bytes ->
      let qtype = qtype_to_u16 q.qtype in
      Some (L.append qname_bytes [
        u16_hi qtype; u16_lo qtype;
        u16_hi q.qclass; u16_lo q.qclass
      ])

let rec serialize_questions_bytes (questions:list question) : option (list FStar.UInt8.t) =
  match questions with
  | [] -> Some []
  | question :: rest ->
      match serialize_question_bytes question, serialize_questions_bytes rest with
      | Some qbytes, Some rest_bytes -> Some (L.append qbytes rest_bytes)
      | _, _ -> None

let serializable_rdata (rtype:qtype) (rdata:list FStar.UInt8.t) : bool =
  let n = L.length rdata in
  if n > 65535 || u16_to_qtype (qtype_to_u16 rtype) <> rtype then false else
  let len = FStar.UInt16.uint_to_t n in
  P.valid_rdata_length rtype len && P.valid_rdata_shape rtype len rdata

let well_formed_record (rr:resource_record) : bool =
  N.dns_name_length rr.name <= 255 &&
  FStar.UInt16.v rr.rdlen = FStar.Bytes.length rr.rdata &&
  serializable_rdata rr.rtype (OPT.bytes_to_list rr.rdata)

let serialize_resource_record_fields_bytes
  (name:N.qname)
  (rtype:qtype)
  (rclass:FStar.UInt16.t)
  (ttl:FStar.UInt32.t)
  (rdata:list FStar.UInt8.t)
  : Tot (result:option (list FStar.UInt8.t){
      Some? result ==> serializable_rdata rtype rdata /\ N.dns_name_length name <= 255})
  =
  let rdlen = L.length rdata in
  if rdlen > 65535 || not (serializable_rdata rtype rdata) then
    None
  else
    match serialize_qname_uncompressed name with
    | None -> None
    | Some name_bytes ->
        let rtype_wire = qtype_to_u16 rtype in
        let rdlen_wire = FStar.UInt16.uint_to_t rdlen in
        Some (L.append name_bytes (L.append [
          u16_hi rtype_wire; u16_lo rtype_wire;
          u16_hi rclass; u16_lo rclass;
          u32_b0 ttl; u32_b1 ttl; u32_b2 ttl; u32_b3 ttl;
          u16_hi rdlen_wire; u16_lo rdlen_wire
        ] rdata))

let serialize_resource_record_bytes (rr:resource_record)
  : Tot (result:option (list FStar.UInt8.t){Some? result ==> well_formed_record rr}) =
  (* Name/RDATA validation is performed once by the fields serializer. *)
  if FStar.UInt16.v rr.rdlen <> FStar.Bytes.length rr.rdata then None else
  serialize_resource_record_fields_bytes
    rr.name
    rr.rtype
    rr.rclass
    rr.ttl
    (OPT.bytes_to_list rr.rdata)

let rec serialize_resource_records_bytes (records:list resource_record) : option (list FStar.UInt8.t) =
  match records with
  | [] -> Some []
  | record :: rest ->
      match serialize_resource_record_bytes record, serialize_resource_records_bytes rest with
      | Some rr_bytes, Some rest_bytes -> Some (L.append rr_bytes rest_bytes)
      | _, _ -> None

let lemma_record_payload_serialization (rr:resource_record) (payload:list FStar.UInt8.t)
  : Lemma (requires (OPT.bytes_to_list rr.rdata == payload /\
      FStar.UInt16.v rr.rdlen == L.length payload))
    (ensures (serialize_resource_record_bytes rr ==
      serialize_resource_record_fields_bytes rr.name rr.rtype rr.rclass rr.ttl payload)) = ()

let header_counts_match (packet:dns_packet) : bool =
  FStar.UInt16.v packet.header.qdcount = L.length packet.questions &&
  FStar.UInt16.v packet.header.ancount = L.length packet.answers &&
  FStar.UInt16.v packet.header.nscount = L.length packet.authorities &&
  FStar.UInt16.v packet.header.arcount = L.length packet.additionals

(* Compare abstract byte values by content, not representation/FFI identity. *)
let rec bytes_equal_from (a:FStar.Bytes.bytes) (b:FStar.Bytes.bytes{FStar.Bytes.length b == FStar.Bytes.length a})
  (pos:nat{pos <= FStar.Bytes.length a})
  : Tot (same:bool{same ==> forall (i:nat). pos <= i /\ i < FStar.Bytes.length a ==>
      FStar.Bytes.index a i == FStar.Bytes.index b i})
    (decreases (FStar.Bytes.length a - pos)) =
  if pos = FStar.Bytes.length a then true else
  FStar.UInt8.eq (FStar.Bytes.index a pos) (FStar.Bytes.index b pos) &&
  bytes_equal_from a b (pos + 1)

let bytes_equal (a:FStar.Bytes.bytes) (b:FStar.Bytes.bytes)
  : Tot (same:bool{same ==> a == b}) =
  if FStar.Bytes.length a <> FStar.Bytes.length b then false else
  if bytes_equal_from a b 0 then
    (FStar.Bytes.extensionality a b; true)
  else false

let record_equal (a:resource_record) (b:resource_record)
  : Tot (same:bool{same ==> a == b}) =
  a.name = b.name && a.rtype = b.rtype && a.rclass = b.rclass &&
  a.ttl = b.ttl && a.rdlen = b.rdlen && bytes_equal a.rdata b.rdata

let rec records_equal (a:list resource_record) (b:list resource_record)
  : Tot (same:bool{same ==> a == b}) =
  match a,b with
  | [],[] -> true
  | x::xs,y::ys -> record_equal x y && records_equal xs ys
  | _ -> false

let packet_equal (a:dns_packet) (b:dns_packet)
  : Tot (same:bool{same ==> a == b}) =
  a.header = b.header && a.questions = b.questions &&
  records_equal a.answers b.answers && records_equal a.authorities b.authorities &&
  records_equal a.additionals b.additionals

let rec lemma_bytes_equal_from_refl (b:FStar.Bytes.bytes) (pos:nat{pos <= FStar.Bytes.length b})
  : Lemma (ensures (bytes_equal_from b b pos))
          (decreases (FStar.Bytes.length b - pos)) =
  if pos < FStar.Bytes.length b then lemma_bytes_equal_from_refl b (pos + 1)

let rec lemma_records_equal_refl (records:list resource_record)
  : Lemma (records_equal records records) =
  match records with
  | [] -> ()
  | rr :: rest -> lemma_bytes_equal_from_refl rr.rdata 0; lemma_records_equal_refl rest

let lemma_packet_equal_refl (packet:dns_packet) : Lemma (packet_equal packet packet) =
  lemma_records_equal_refl packet.answers;
  lemma_records_equal_refl packet.authorities;
  lemma_records_equal_refl packet.additionals

let serialize_dns_packet_bytes (packet:dns_packet)
  : Tot (result:option (list FStar.UInt8.t){
      match result with
      | Some bytes -> P.parse_dns_packet_bytes bytes == Some packet
      | None -> True}) =
  if not (header_counts_match packet) then
    None
  else
    match serialize_questions_bytes packet.questions,
          serialize_resource_records_bytes packet.answers,
          serialize_resource_records_bytes packet.authorities,
          serialize_resource_records_bytes packet.additionals with
    | Some question_bytes,
      Some answer_bytes,
      Some authority_bytes,
      Some additional_bytes ->
        let bytes =
          L.append (serialize_header_bytes packet.header)
            (L.append question_bytes
              (L.append answer_bytes
                (L.append authority_bytes additional_bytes))) in
        (* The general list-backed serializer is a checked construction layer.
           This check also rejects packet-relative compressed RDATA relocation.
           Completeness is not assumed: only successful round-trips are exposed. *)
        (match P.parse_dns_packet_bytes bytes with
         | Some parsed -> if packet_equal parsed packet then Some bytes else None
         | None -> None)
    | _, _, _, _ -> None

let lemma_serialized_packet_roundtrip (packet:dns_packet) (bytes:list FStar.UInt8.t)
  : Lemma (requires (serialize_dns_packet_bytes packet == Some bytes))
          (ensures (P.parse_dns_packet_bytes bytes == Some packet)) = ()

(* A compositional success rule, useful when byte arrays are abstract to the
   normalizer: validate sections and parse-back separately, then compose. *)
let lemma_checked_packet_serialization (packet:dns_packet)
  (qs:list FStar.UInt8.t) (answers:list FStar.UInt8.t)
  (authorities:list FStar.UInt8.t) (additionals:list FStar.UInt8.t)
  : Lemma (requires (header_counts_match packet /\
      serialize_questions_bytes packet.questions == Some qs /\
      serialize_resource_records_bytes packet.answers == Some answers /\
      serialize_resource_records_bytes packet.authorities == Some authorities /\
      serialize_resource_records_bytes packet.additionals == Some additionals /\
      P.parse_dns_packet_bytes (L.append (serialize_header_bytes packet.header)
        (L.append qs (L.append answers (L.append authorities additionals)))) == Some packet))
    (ensures (serialize_dns_packet_bytes packet == Some
      (L.append (serialize_header_bytes packet.header)
        (L.append qs (L.append answers (L.append authorities additionals)))))) =
  lemma_packet_equal_refl packet

let response_flags_from_request (request_header:header) (rcode:R.rcode) : dns_flags =
  {
    qr = true;
    opcode = request_header.flags.opcode;
    aa = false;
    tc = false;
    rd = request_header.flags.rd;
    ra = false;
    z = false;
    ad = false;
    cd = request_header.flags.cd;
    rcode = R.rcode_to_u4 rcode;
  }

let build_minimal_response_packet
  (request:dns_packet)
  (rcode:R.rcode)
  : option dns_packet
  =
  let qd = L.length request.questions in
  if qd > 65535 then
    None
  else
    Some {
      header = {
        id = request.header.id;
        flags = response_flags_from_request request.header rcode;
        qdcount = FStar.UInt16.uint_to_t qd;
        ancount = 0us;
        nscount = 0us;
        arcount = 0us;
      };
      questions = request.questions;
      answers = [];
      authorities = [];
      additionals = [];
    }

let serialize_minimal_response_bytes
  (request:dns_packet)
  (rcode:R.rcode)
  : option (list FStar.UInt8.t)
  =
  match build_minimal_response_packet request rcode with
  | Some response -> serialize_dns_packet_bytes response
  | None -> None

let build_result_response_packet
  (request:dns_packet)
  (result:R.dns_result)
  : option dns_packet
  =
  let qd = L.length request.questions in
  if qd > 65535 then
    None
  else
    let response_rcode, response_answers =
      match result with
      | R.Success records -> R.NoError, records
      | R.Error rcode -> rcode, [] in
    let an = L.length response_answers in
    if an > 65535 then
      None
    else
      Some {
        header = {
          id = request.header.id;
          flags = response_flags_from_request request.header response_rcode;
          qdcount = FStar.UInt16.uint_to_t qd;
          ancount = FStar.UInt16.uint_to_t an;
          nscount = 0us;
          arcount = 0us;
        };
        questions = request.questions;
        answers = response_answers;
        authorities = [];
        additionals = [];
      }

let serialize_result_response_bytes
  (request:dns_packet)
  (result:R.dns_result)
  : option (list FStar.UInt8.t)
  =
  match build_result_response_packet request result with
  | Some response -> serialize_dns_packet_bytes response
  | None -> None

let serialize_response_with_opt_payload
  (h:header)
  (udp_payload_size:FStar.UInt16.t)
  (ext_rcode:FStar.UInt8.t)
  (version:FStar.UInt8.t)
  (flags:OPT.opt_flags)
  (option_payload:list FStar.UInt8.t)
  : option (list FStar.UInt8.t)
  =
  match OPT.serialize_opt_rr_bytes_with_payload
          udp_payload_size
          ext_rcode
          version
          flags
          option_payload with
  | Some opt_rr -> Some (L.append (serialize_header_bytes h) opt_rr)
  | None -> None

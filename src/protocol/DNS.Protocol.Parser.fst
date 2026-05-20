module DNS.Protocol.Parser

open FStar.UInt16
open FStar.HyperStack.ST
open DNS.Protocol
open DNS.Constants
module L = FStar.List.Tot
module LPP = FStar.List.Pure.Properties
module OPT = DNS.Protocol.OPT
module EPR = DNS.Protocol.Parser.EverParseRuntime

(* --- Flag Mapping --- *)

let uint16_to_flags (raw_flags: FStar.UInt16.t) : dns_flags =
  let raw = FStar.UInt16.v raw_flags in
  {
    qr     = raw / 32768 = 1;
    opcode = FStar.UInt16.uint_to_t ((raw / 2048) % 16);
    aa     = (raw / 1024) % 2 = 1;
    tc     = (raw / 512) % 2 = 1;
    rd     = (raw / 256) % 2 = 1;
    ra     = (raw / 128) % 2 = 1;
    z      = (raw / 64) % 2 = 1;
    ad     = (raw / 32) % 2 = 1;
    cd     = (raw / 16) % 2 = 1;
    rcode  = FStar.UInt16.uint_to_t (raw % 16);
  }

(* --- Header Parser --- *)

type raw_header = (FStar.UInt16.t * (FStar.UInt16.t * (FStar.UInt16.t * (FStar.UInt16.t * (FStar.UInt16.t * FStar.UInt16.t)))))

let raw_header_to_header (r: raw_header) : header =
  let (id, (flags_raw, (qd, (an, (ns, ar))))) = r in
  {
    id      = id;
    flags   = uint16_to_flags flags_raw;
    qdcount = qd;
    ancount = an;
    nscount = ns;
    arcount = ar;
  }

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

val has_header_bytes :
  need:nat ->
  input:list FStar.UInt8.t ->
  Tot bool (decreases need)

let rec has_header_bytes need input =
  if need = 0 then true
  else
    match input with
    | [] -> false
    | _ :: tl -> has_header_bytes (need - 1) tl

val parse_header_bytes :
  input:list FStar.UInt8.t ->
  Tot (option (header * list FStar.UInt8.t))

let parse_header_bytes input =
  if L.length input < 12 then
    None
  else
    match input with
    | id_hi :: id_lo ::
      fl_hi :: fl_lo ::
      qd_hi :: qd_lo ::
      an_hi :: an_lo ::
      ns_hi :: ns_lo ::
      ar_hi :: ar_lo ::
      rest ->
        Some (
          raw_header_to_header (
            u16_from_be id_hi id_lo,
            (u16_from_be fl_hi fl_lo,
            (u16_from_be qd_hi qd_lo,
            (u16_from_be an_hi an_lo,
            (u16_from_be ns_hi ns_lo,
             u16_from_be ar_hi ar_lo))))),
          rest)
    | _ -> None

val lemma_parse_header_rejects_short :
  input:list FStar.UInt8.t{L.length input < 12} ->
  Lemma (ensures (parse_header_bytes input == None))

val lemma_has_header_bytes_iff_length :
  need:nat ->
  input:list FStar.UInt8.t ->
  Lemma (ensures (has_header_bytes need input == true <==> L.length input >= need))
        (decreases need)

let rec lemma_has_header_bytes_iff_length need input =
  if need = 0 then ()
  else
    match input with
    | [] -> ()
    | _ :: tl -> lemma_has_header_bytes_iff_length (need - 1) tl

let lemma_parse_header_rejects_short input =
  ()

val lemma_parse_header_success_length :
  input:list FStar.UInt8.t ->
  Lemma (ensures (match parse_header_bytes input with
                  | Some _ -> L.length input >= 12
                  | None -> True))

let lemma_parse_header_success_length input =
  ()

val lemma_parse_header_success_not_short :
  input:list FStar.UInt8.t ->
  h:header ->
  rest:list FStar.UInt8.t ->
  Lemma (requires (parse_header_bytes input == Some (h, rest)))
        (ensures (L.length input >= 12))

let lemma_parse_header_success_not_short input h rest =
  lemma_parse_header_success_length input

let has_question_suffix (input:list FStar.UInt8.t) : bool =
  match input with
  | _qt_hi :: _qt_lo :: _qc_hi :: _qc_lo :: _ -> true
  | _ -> false

val parse_question_bytes :
  input:list FStar.UInt8.t ->
  Tot (option (question * list FStar.UInt8.t))

let parse_question_bytes input =
  match DNS.Name.parse_qname 128 input with
  | None -> None
  | Some (name, rest) ->
      match rest with
      | qt_hi :: qt_lo :: qc_hi :: qc_lo :: tail ->
          Some ({
            qname = name;
            qtype = u16_to_qtype (u16_from_be qt_hi qt_lo);
            qclass = u16_from_be qc_hi qc_lo;
          }, tail)
      | _ -> None

val lemma_parse_question_success_qname :
  input:list FStar.UInt8.t ->
  q:question ->
  tail:list FStar.UInt8.t ->
  Lemma (requires (parse_question_bytes input == Some (q, tail)))
        (ensures (exists rest. DNS.Name.parse_qname 128 input == Some (q.qname, rest) /\ has_question_suffix rest == true))

let lemma_parse_question_success_qname input q tail =
  match DNS.Name.parse_qname 128 input with
  | None -> ()
  | Some (name, rest) ->
      match rest with
      | _qt_hi :: _qt_lo :: _qc_hi :: _qc_lo :: _ -> ()
      | _ -> ()

val lemma_parse_question_consumption :
  input:list FStar.UInt8.t ->
  Lemma (ensures (match parse_question_bytes input with
                  | Some (_, tail) -> L.length tail < L.length input
                  | None -> True))

let lemma_parse_question_consumption input =
  DNS.Name.lemma_parse_qname_consumption 128 input;
  match DNS.Name.parse_qname 128 input with
  | None -> ()
  | Some (_, rest) ->
      match rest with
      | _qt_hi :: _qt_lo :: _qc_hi :: _qc_lo :: _tail -> ()
      | _ -> ()

val lemma_parse_question_success_suffix :
  input:list FStar.UInt8.t ->
  q:question ->
  tail:list FStar.UInt8.t ->
  Lemma (requires (parse_question_bytes input == Some (q, tail)))
        (ensures (exists rest. DNS.Name.parse_qname 128 input == Some (q.qname, rest) /\ L.length rest >= 4))

let lemma_parse_question_success_suffix input q tail =
  lemma_parse_question_success_qname input q tail

val parse_questions_bytes :
  fuel:nat ->
  count:nat ->
  input:list FStar.UInt8.t ->
  Tot (option (list question * list FStar.UInt8.t)) (decreases fuel)

let rec parse_questions_bytes fuel count input =
  if count = 0 then Some ([], input)
  else if fuel = 0 then None
  else
    match parse_question_bytes input with
    | None -> None
    | Some (q, rest) ->
        match parse_questions_bytes (fuel - 1) (count - 1) rest with
        | None -> None
        | Some (qs, tail) -> Some (q :: qs, tail)

val parse_rdata_bytes :
  rdlen:FStar.UInt16.t ->
  input:list FStar.UInt8.t ->
  Tot (option (FStar.Bytes.bytes * list FStar.UInt8.t))

let parse_rdata_bytes rdlen input =
  let len = FStar.UInt16.v rdlen in
  if L.length input < len then
    None
  else
    let (rdata, tail) = L.splitAt len input in
    LPP.splitAt_length len input;
    assert (L.length rdata == len);
    let len32 = FStar.UInt32.uint_to_t len in
    assert (FStar.UInt32.v len32 == len);
    Some (FStar.Bytes.init len32 (fun i -> L.index rdata (FStar.UInt32.v i)), tail)

val valid_rdata_length :
  rtype:qtype ->
  rdlen:FStar.UInt16.t ->
  Tot bool

let valid_rdata_length rtype rdlen =
  match rtype with
  | A -> rdlen = 4us
  | AAAA -> rdlen = 16us
  | _ -> true

let edns_version_from_ttl (ttl:FStar.UInt32.t) : FStar.UInt8.t =
  FStar.UInt8.uint_to_t ((FStar.UInt32.v ttl / 65536) % 256)

val valid_rr_position_and_shape :
  additional_section:bool ->
  name:DNS.Name.qname ->
  rtype:qtype ->
  ttl:FStar.UInt32.t ->
  Tot bool

let valid_rr_position_and_shape additional_section name rtype ttl =
  match rtype with
  | OPT ->
      additional_section &&
      name = [] &&
      edns_version_from_ttl ttl = 0uy
  | _ -> true

val valid_opt_options_payload :
  rdlen:FStar.UInt16.t ->
  input:list FStar.UInt8.t ->
  Tot bool

let valid_opt_options_payload rdlen input =
  let len = FStar.UInt16.v rdlen in
  if L.length input < len then
    false
  else
    let (payload, _) = L.splitAt len input in
    match OPT.parse_edns_options_bytes len payload with
    | Some _ -> true
    | None -> false

val valid_name_rdata_payload :
  rdlen:FStar.UInt16.t ->
  input:list FStar.UInt8.t ->
  Tot bool

let valid_name_rdata_payload rdlen input =
  let len = FStar.UInt16.v rdlen in
  if L.length input < len then
    false
  else
    let (payload, _) = L.splitAt len input in
    match DNS.Name.parse_qname 128 payload with
    | Some (_, tail) -> L.length tail = 0
    | None -> false

val valid_name_rdata_payload_at :
  original:list FStar.UInt8.t ->
  rdata_offset:nat ->
  rdlen:FStar.UInt16.t ->
  input:list FStar.UInt8.t ->
  Tot bool

let valid_name_rdata_payload_at original rdata_offset rdlen input =
  let len = FStar.UInt16.v rdlen in
  if L.length input < len then
    false
  else
    let (payload, _) = L.splitAt len input in
    match DNS.Name.parse_qname_compressed 128 original rdata_offset payload with
    | Some (_, tail) -> L.length tail = 0
    | None -> false

val valid_mx_rdata_payload :
  rdlen:FStar.UInt16.t ->
  input:list FStar.UInt8.t ->
  Tot bool

let valid_mx_rdata_payload rdlen input =
  let len = FStar.UInt16.v rdlen in
  if len < 3 || L.length input < len then
    false
  else
    let (payload, _) = L.splitAt len input in
    match payload with
    | _pref_hi :: _pref_lo :: exchange ->
        match DNS.Name.parse_qname 128 exchange with
        | Some (_, tail) -> L.length tail = 0
        | None -> false
    | _ -> false

val valid_mx_rdata_payload_at :
  original:list FStar.UInt8.t ->
  rdata_offset:nat ->
  rdlen:FStar.UInt16.t ->
  input:list FStar.UInt8.t ->
  Tot bool

let valid_mx_rdata_payload_at original rdata_offset rdlen input =
  let len = FStar.UInt16.v rdlen in
  if len < 3 || L.length input < len then
    false
  else
    let (payload, _) = L.splitAt len input in
    match payload with
    | _pref_hi :: _pref_lo :: exchange ->
        match DNS.Name.parse_qname_compressed 128 original (rdata_offset + 2) exchange with
        | Some (_, tail) -> L.length tail = 0
        | None -> false
    | _ -> false

val valid_soa_rdata_payload :
  rdlen:FStar.UInt16.t ->
  input:list FStar.UInt8.t ->
  Tot bool

let valid_soa_rdata_after_mname input =
  match DNS.Name.parse_qname 128 input with
  | Some (_, timers) -> L.length timers = 20
  | None -> false

let valid_soa_rdata_payload rdlen input =
  let len = FStar.UInt16.v rdlen in
  if len < 22 || L.length input < len then
    false
  else
    let (payload, _) = L.splitAt len input in
    match DNS.Name.parse_qname 128 payload with
    | Some (_, after_mname) -> valid_soa_rdata_after_mname after_mname
    | None -> false

val valid_soa_rdata_payload_at :
  original:list FStar.UInt8.t ->
  rdata_offset:nat ->
  rdlen:FStar.UInt16.t ->
  input:list FStar.UInt8.t ->
  Tot bool

let valid_soa_rdata_payload_at original rdata_offset rdlen input =
  let len = FStar.UInt16.v rdlen in
  if len < 22 || L.length input < len then
    false
  else
    let (payload, _) = L.splitAt len input in
    match DNS.Name.parse_qname_compressed 128 original rdata_offset payload with
    | Some (_, after_mname) ->
        let mname_consumed =
          if L.length after_mname <= L.length payload then
            L.length payload - L.length after_mname
          else
            0 in
        let rname_offset = rdata_offset + mname_consumed in
        begin match DNS.Name.parse_qname_compressed 128 original rname_offset after_mname with
        | Some (_, timers) -> L.length timers = 20
        | None -> false
        end
    | None -> false

val valid_txt_strings :
  fuel:nat ->
  input:list FStar.UInt8.t ->
  Tot bool (decreases fuel)

let rec valid_txt_strings fuel input =
  if L.length input = 0 then
    true
  else if fuel = 0 then
    false
  else
    match input with
    | slen_b :: rest ->
        let slen = FStar.UInt8.v slen_b in
        if L.length rest < slen then
          false
        else
          let (_, tail) = L.splitAt slen rest in
          valid_txt_strings (fuel - 1) tail
    | [] -> true

val valid_txt_rdata_payload :
  rdlen:FStar.UInt16.t ->
  input:list FStar.UInt8.t ->
  Tot bool

let valid_txt_rdata_payload rdlen input =
  let len = FStar.UInt16.v rdlen in
  if len = 0 || L.length input < len then
    false
  else
    let (payload, _) = L.splitAt len input in
    valid_txt_strings len payload

val valid_srv_rdata_payload :
  rdlen:FStar.UInt16.t ->
  input:list FStar.UInt8.t ->
  Tot bool

let valid_srv_rdata_payload rdlen input =
  let len = FStar.UInt16.v rdlen in
  if len < 7 || L.length input < len then
    false
  else
    let (payload, _) = L.splitAt len input in
    match payload with
    | _priority_hi :: _priority_lo ::
      _weight_hi :: _weight_lo ::
      _port_hi :: _port_lo ::
      target ->
        match DNS.Name.parse_qname 128 target with
        | Some (_, tail) -> L.length tail = 0
        | None -> false
    | _ -> false

val valid_srv_rdata_payload_at :
  original:list FStar.UInt8.t ->
  rdata_offset:nat ->
  rdlen:FStar.UInt16.t ->
  input:list FStar.UInt8.t ->
  Tot bool

let valid_srv_rdata_payload_at original rdata_offset rdlen input =
  let len = FStar.UInt16.v rdlen in
  if len < 7 || L.length input < len then
    false
  else
    let (payload, _) = L.splitAt len input in
    match payload with
    | _priority_hi :: _priority_lo ::
      _weight_hi :: _weight_lo ::
      _port_hi :: _port_lo ::
      target ->
        match DNS.Name.parse_qname_compressed 128 original (rdata_offset + 6) target with
        | Some (_, tail) -> L.length tail = 0
        | None -> false
    | _ -> false

val valid_rdata_shape :
  rtype:qtype ->
  rdlen:FStar.UInt16.t ->
  input:list FStar.UInt8.t ->
  Tot bool

let valid_rdata_shape rtype rdlen input =
  match rtype with
  | OPT -> valid_opt_options_payload rdlen input
  | NS -> valid_name_rdata_payload rdlen input
  | CNAME -> valid_name_rdata_payload rdlen input
  | PTR -> valid_name_rdata_payload rdlen input
  | MX -> valid_mx_rdata_payload rdlen input
  | SOA -> valid_soa_rdata_payload rdlen input
  | TXT -> valid_txt_rdata_payload rdlen input
  | SRV -> valid_srv_rdata_payload rdlen input
  | _ -> true

val valid_rdata_shape_at :
  original:list FStar.UInt8.t ->
  rdata_offset:nat ->
  rtype:qtype ->
  rdlen:FStar.UInt16.t ->
  input:list FStar.UInt8.t ->
  Tot bool

let valid_rdata_shape_at original rdata_offset rtype rdlen input =
  match rtype with
  | NS -> valid_name_rdata_payload_at original rdata_offset rdlen input
  | CNAME -> valid_name_rdata_payload_at original rdata_offset rdlen input
  | PTR -> valid_name_rdata_payload_at original rdata_offset rdlen input
  | MX -> valid_mx_rdata_payload_at original rdata_offset rdlen input
  | SOA -> valid_soa_rdata_payload_at original rdata_offset rdlen input
  | SRV -> valid_srv_rdata_payload_at original rdata_offset rdlen input
  | _ -> valid_rdata_shape rtype rdlen input

val parse_resource_record_bytes :
  additional_section:bool ->
  input:list FStar.UInt8.t ->
  Tot (option (resource_record * list FStar.UInt8.t))

let parse_resource_record_bytes additional_section input =
  match DNS.Name.parse_qname 128 input with
  | None -> None
  | Some (name, rest) ->
      if L.length rest < 10 then
        None
      else
        match rest with
        | rt_hi :: rt_lo ::
          rc_hi :: rc_lo ::
          ttl_0 :: ttl_1 :: ttl_2 :: ttl_3 ::
          rdlen_hi :: rdlen_lo ::
          rdata_input ->
            let rdlen = u16_from_be rdlen_hi rdlen_lo in
            let rtype = u16_to_qtype (u16_from_be rt_hi rt_lo) in
            let ttl = u32_from_be ttl_0 ttl_1 ttl_2 ttl_3 in
            if valid_rr_position_and_shape additional_section name rtype ttl &&
               valid_rdata_length rtype rdlen &&
               valid_rdata_shape rtype rdlen rdata_input then
              match parse_rdata_bytes rdlen rdata_input with
              | None -> None
              | Some (rdata, tail) ->
                  Some ({
                    name = name;
                    rtype = rtype;
                    rclass = u16_from_be rc_hi rc_lo;
                    ttl = ttl;
                    rdlen = rdlen;
                    rdata = rdata;
                  }, tail)
            else
              None
        | _ -> None

let offset_from_tail (original:list FStar.UInt8.t) (tail:list FStar.UInt8.t) : nat =
  if L.length tail <= L.length original then
    L.length original - L.length tail
  else
    0

val parse_resource_record_bytes_at :
  original:list FStar.UInt8.t ->
  current_offset:nat ->
  additional_section:bool ->
  input:list FStar.UInt8.t ->
  Tot (option (resource_record * list FStar.UInt8.t))

let parse_resource_record_bytes_at original current_offset additional_section input =
  match DNS.Name.parse_qname_compressed 128 original current_offset input with
  | None -> None
  | Some (name, rest) ->
      if L.length rest < 10 then
        None
      else
        match rest with
        | rt_hi :: rt_lo ::
          rc_hi :: rc_lo ::
          ttl_0 :: ttl_1 :: ttl_2 :: ttl_3 ::
          rdlen_hi :: rdlen_lo ::
          rdata_input ->
            let rdlen = u16_from_be rdlen_hi rdlen_lo in
            let rtype = u16_to_qtype (u16_from_be rt_hi rt_lo) in
            let ttl = u32_from_be ttl_0 ttl_1 ttl_2 ttl_3 in
            let name_consumed = offset_from_tail input rest in
            let rdata_offset = current_offset + name_consumed + 10 in
            if valid_rr_position_and_shape additional_section name rtype ttl &&
               valid_rdata_length rtype rdlen &&
               valid_rdata_shape_at original rdata_offset rtype rdlen rdata_input then
              match parse_rdata_bytes rdlen rdata_input with
              | None -> None
              | Some (rdata, tail) ->
                  Some ({
                    name = name;
                    rtype = rtype;
                    rclass = u16_from_be rc_hi rc_lo;
                    ttl = ttl;
                    rdlen = rdlen;
                    rdata = rdata;
                  }, tail)
            else
              None
        | _ -> None

val parse_resource_records_bytes :
  additional_section:bool ->
  fuel:nat ->
  count:nat ->
  input:list FStar.UInt8.t ->
  Tot (option (list resource_record * list FStar.UInt8.t)) (decreases fuel)

let rec parse_resource_records_bytes additional_section fuel count input =
  if count = 0 then Some ([], input)
  else if fuel = 0 then None
  else
    match parse_resource_record_bytes additional_section input with
    | None -> None
    | Some (rr, rest) ->
        match parse_resource_records_bytes additional_section (fuel - 1) (count - 1) rest with
        | None -> None
        | Some (rrs, tail) -> Some (rr :: rrs, tail)

val parse_resource_records_bytes_at :
  original:list FStar.UInt8.t ->
  current_offset:nat ->
  additional_section:bool ->
  fuel:nat ->
  count:nat ->
  input:list FStar.UInt8.t ->
  Tot (option (list resource_record * list FStar.UInt8.t)) (decreases fuel)

let rec parse_resource_records_bytes_at original current_offset additional_section fuel count input =
  if count = 0 then Some ([], input)
  else if fuel = 0 then None
  else
    match parse_resource_record_bytes_at original current_offset additional_section input with
    | None -> None
    | Some (rr, rest) ->
        let consumed =
          if L.length rest <= L.length input then
            L.length input - L.length rest
          else
            0 in
        match parse_resource_records_bytes_at
                original
                (current_offset + consumed)
                additional_section
                (fuel - 1)
                (count - 1)
                rest with
        | None -> None
        | Some (rrs, tail) -> Some (rr :: rrs, tail)

val parse_dns_packet_bytes :
  input:list FStar.UInt8.t ->
  Tot (option dns_packet)

let parse_dns_packet_bytes input =
  match parse_header_bytes input with
  | None -> None
  | Some (h, rest) ->
      let qd = FStar.UInt16.v h.qdcount in
      let an = FStar.UInt16.v h.ancount in
      let ns = FStar.UInt16.v h.nscount in
      let ar = FStar.UInt16.v h.arcount in
      match parse_questions_bytes qd qd rest with
      | None -> None
      | Some (qs, after_questions) ->
          let answer_offset = offset_from_tail input after_questions in
          match parse_resource_records_bytes_at input answer_offset false an an after_questions with
          | None -> None
          | Some (answers, after_answers) ->
              let authority_offset = offset_from_tail input after_answers in
              match parse_resource_records_bytes_at input authority_offset false ns ns after_answers with
              | None -> None
              | Some (authorities, after_authorities) ->
                  let additional_offset = offset_from_tail input after_authorities in
                  match parse_resource_records_bytes_at input additional_offset true ar ar after_authorities with
                  | None -> None
                  | Some (additionals, tail) ->
                      if L.length tail = 0 then
                        Some {
                          header = h;
                          questions = qs;
                          answers = answers;
                          authorities = authorities;
                          additionals = additionals;
                        }
                      else
                        None

let validate_dns_packet_bytes (input:list FStar.UInt8.t) : bool =
  match parse_dns_packet_bytes input with
  | Some _ -> true
  | None -> false

val parse_dns_packet_buffer :
  buffer:LowStar.Buffer.buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack (option dns_packet)
    (requires (fun h0 ->
      LowStar.Buffer.live h0 buffer /\
      FStar.UInt32.v len <= LowStar.Buffer.length buffer))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

val generated_uncompressed_question_qname_length :
  input:list FStar.UInt8.t ->
  Tot nat

let generated_uncompressed_question_qname_length input =
  if L.length input < 17 || L.length input > 271 then
    0
  else
    let (_, question_input) = L.splitAt 12 input in
    match DNS.Name.parse_qname 128 question_input with
    | Some (name, rest) ->
        if L.length rest = 4 then
          DNS.Name.dns_name_length name
        else
          0
    | None -> 0

val generated_uncompressed_question_subset_applicable :
  input:list FStar.UInt8.t ->
  Tot bool

let generated_uncompressed_question_subset_applicable input =
  let qname_length = generated_uncompressed_question_qname_length input in
  if qname_length = 0 || qname_length > 255 then
    false
  else
    L.length input = 16 + qname_length

val generated_uncompressed_question_answer_packet_lengths :
  input:list FStar.UInt8.t ->
  Tot (option (nat * nat * nat))

type generated_dns_name_length = n:nat{n > 0 /\ n <= 255}

val generated_uncompressed_question_answer_packet_fields :
  input:list FStar.UInt8.t ->
  Tot (option (nat * nat * nat * nat * bool * option generated_dns_name_length * option generated_dns_name_length))

let generated_uncompressed_question_answer_packet_fields input =
  if L.length input < 28 || L.length input > 66071 then
    None
  else
    match parse_header_bytes input with
    | Some (h, after_header) ->
        if FStar.UInt16.v h.qdcount = 1 &&
           FStar.UInt16.v h.ancount = 1 &&
           FStar.UInt16.v h.nscount = 0 &&
           FStar.UInt16.v h.arcount = 0 then
          match DNS.Name.parse_qname 128 after_header with
          | Some (question_name, question_tail) ->
              if L.length question_tail < 4 then
                None
              else
                let question_qname_length = DNS.Name.dns_name_length question_name in
                let (_, after_question) = L.splitAt 4 question_tail in
                begin match DNS.Name.parse_qname 128 after_question with
                | Some (rr_name, rr_tail) ->
                    begin match rr_tail with
                    | _rt_hi :: _rt_lo ::
                      _rc_hi :: _rc_lo ::
                      _ttl_0 :: _ttl_1 :: _ttl_2 :: _ttl_3 ::
                      rdlen_hi :: rdlen_lo ::
                      rdata_tail ->
                        let rr_type = FStar.UInt16.v (u16_from_be _rt_hi _rt_lo) in
                        let rdata_length =
                          FStar.UInt16.v (u16_from_be rdlen_hi rdlen_lo) in
                        let rdata_name_starts_with_pointer =
                          if rr_type = 2 || rr_type = 5 || rr_type = 12 then
                            match rdata_tail with
                            | b :: _ -> DNS.Name.is_pointer b
                            | _ -> false
                          else if rr_type = 6 then
                            match rdata_tail with
                            | b :: _ ->
                                DNS.Name.is_pointer b ||
                                begin match DNS.Name.parse_qname 128 rdata_tail with
                                | Some (_, after_mname) ->
                                    begin match after_mname with
                                    | rb :: _ -> DNS.Name.is_pointer rb
                                    | _ -> false
                                    end
                                | None -> false
                                end
                            | _ -> false
                          else if rr_type = 15 then
                            match rdata_tail with
                            | _pref_hi :: _pref_lo :: b :: _ -> DNS.Name.is_pointer b
                            | _ -> false
                          else if rr_type = 33 then
                            match rdata_tail with
                            | _priority_hi :: _priority_lo ::
                              _weight_hi :: _weight_lo ::
                              _port_hi :: _port_lo ::
                              b :: _ -> DNS.Name.is_pointer b
                            | _ -> false
                          else
                            false in
                        let rdata_name_length =
                          if rr_type = 2 || rr_type = 5 || rr_type = 12 then
                            match DNS.Name.parse_qname 128 rdata_tail with
                            | Some (rdata_name, _) ->
                                DNS.Name.lemma_parser_rejecting 128 rdata_tail;
                                let rdata_name_length = DNS.Name.dns_name_length rdata_name in
                                assert (rdata_name_length > 0);
                                assert (rdata_name_length <= 255);
                                Some rdata_name_length
                            | None -> None
                          else if rr_type = 15 then
                            begin match rdata_tail with
                            | _pref_hi :: _pref_lo :: exchange_tail ->
                                begin match DNS.Name.parse_qname 128 exchange_tail with
                                | Some (exchange_name, _) ->
                                    DNS.Name.lemma_parser_rejecting 128 exchange_tail;
                                    let exchange_name_length = DNS.Name.dns_name_length exchange_name in
                                    assert (exchange_name_length > 0);
                                    assert (exchange_name_length <= 255);
                                    Some exchange_name_length
                                | None -> None
                                end
                            | _ -> None
                            end
                          else if rr_type = 6 then
                            match DNS.Name.parse_qname 128 rdata_tail with
                            | Some (mname, _) ->
                                DNS.Name.lemma_parser_rejecting 128 rdata_tail;
                                let mname_length = DNS.Name.dns_name_length mname in
                                assert (mname_length > 0);
                                assert (mname_length <= 255);
                                Some mname_length
                            | None -> None
                          else if rr_type = 33 then
                            begin match rdata_tail with
                            | _priority_hi :: _priority_lo ::
                              _weight_hi :: _weight_lo ::
                              _port_hi :: _port_lo ::
                              target_tail ->
                                begin match DNS.Name.parse_qname 128 target_tail with
                                | Some (target_name, _) ->
                                    DNS.Name.lemma_parser_rejecting 128 target_tail;
                                    let target_name_length = DNS.Name.dns_name_length target_name in
                                    assert (target_name_length > 0);
                                    assert (target_name_length <= 255);
                                    Some target_name_length
                                | None -> None
                                end
                            | _ -> None
                            end
                          else
                            None in
                        let soa_rname_length =
                          if rr_type = 6 then
                            begin match DNS.Name.parse_qname 128 rdata_tail with
                            | Some (_, after_mname) ->
                                begin match DNS.Name.parse_qname 128 after_mname with
                                | Some (rname, _) ->
                                    DNS.Name.lemma_parser_rejecting 128 after_mname;
                                    let rname_length = DNS.Name.dns_name_length rname in
                                    assert (rname_length > 0);
                                    assert (rname_length <= 255);
                                    Some rname_length
                                | None -> None
                                end
                            | None -> None
                            end
                          else
                            None in
                        if rr_type = 1 ||
                           rr_type = 28 ||
                           rr_type = 6 ||
                           rr_type = 2 ||
                           rr_type = 5 ||
                           rr_type = 12 ||
                           rr_type = 15 ||
                           rr_type = 33 ||
                           rr_type = 16 ||
                           L.length rdata_tail = rdata_length then
                          Some (
                            question_qname_length,
                            DNS.Name.dns_name_length rr_name,
                            rdata_length,
                            rr_type,
                            rdata_name_starts_with_pointer,
                            rdata_name_length,
                            soa_rname_length
                          )
                        else
                          None
                    | _ -> None
                    end
                | None -> None
                end
          | None -> None
        else
          None
    | None -> None

let generated_uncompressed_question_answer_packet_lengths input =
  match generated_uncompressed_question_answer_packet_fields input with
  | Some (qname_length, rr_name_length, rdata_length, _, _, _, _) ->
      Some (qname_length, rr_name_length, rdata_length)
  | None -> None

val generated_uncompressed_question_answer_packet_subset_applicable :
  input:list FStar.UInt8.t ->
  Tot bool

let generated_uncompressed_question_answer_packet_subset_applicable input =
  match generated_uncompressed_question_answer_packet_fields input with
  | Some (qname_length, rr_name_length, rdata_length, rr_type, rdata_name_starts_with_pointer, rdata_name_length_opt, _) ->
      qname_length > 0 &&
      qname_length <= 255 &&
      rr_name_length > 0 &&
      rr_name_length <= 255 &&
      rdata_length <= 65535 &&
      (if rr_type = 1 then
         true
       else if rr_type = 28 then
         true
       else if rr_type = 2 || rr_type = 5 || rr_type = 12 then
         (match rdata_name_length_opt with
          | Some _ -> true
          | None -> L.length input <> 26 + qname_length + rr_name_length + rdata_length)
       else if rr_type = 15 then
         (match rdata_name_length_opt with
          | Some _ -> true
          | None ->
              (not rdata_name_starts_with_pointer) ||
              L.length input <> 26 + qname_length + rr_name_length + rdata_length)
       else if rr_type = 6 then
         (not rdata_name_starts_with_pointer) ||
         L.length input <> 26 + qname_length + rr_name_length + rdata_length
       else if rr_type = 33 then
         (match rdata_name_length_opt with
          | Some _ -> true
          | None ->
              (not rdata_name_starts_with_pointer) ||
              L.length input <> 26 + qname_length + rr_name_length + rdata_length)
       else if rr_type = 16 then
         true
       else
         L.length input = 26 + qname_length + rr_name_length + rdata_length)
  | None -> false

val generated_compressed_answer_name_packet_fields :
  input:list FStar.UInt8.t ->
  Tot (option (generated_dns_name_length * nat * nat))

let generated_compressed_answer_name_packet_fields input =
  match parse_header_bytes input with
  | Some (h, after_header) ->
      if FStar.UInt16.v h.qdcount = 1 &&
         FStar.UInt16.v h.ancount = 1 &&
         FStar.UInt16.v h.nscount = 0 &&
         FStar.UInt16.v h.arcount = 0 then
        match DNS.Name.parse_qname 128 after_header with
        | Some (question_name, question_tail) ->
            DNS.Name.lemma_parser_rejecting 128 after_header;
            let qname_length_nat = DNS.Name.dns_name_length question_name in
            assert (qname_length_nat > 0);
            assert (qname_length_nat <= 255);
            let qname_length:generated_dns_name_length = qname_length_nat in
            if L.length question_tail < 4 then
              None
            else
              let (_, after_question) = L.splitAt 4 question_tail in
              begin match after_question with
              | ptr_hi :: ptr_lo ::
                rt_hi :: rt_lo ::
                _rc_hi :: _rc_lo ::
                _ttl_0 :: _ttl_1 :: _ttl_2 :: _ttl_3 ::
                rdlen_hi :: rdlen_lo ::
                rdata_tail ->
                  let rr_type = FStar.UInt16.v (u16_from_be rt_hi rt_lo) in
                  let rdata_length:nat = FStar.UInt16.v (u16_from_be rdlen_hi rdlen_lo) in
                  if ptr_hi = 0xc0uy &&
                     ptr_lo = 0x0cuy &&
                     L.length rdata_tail = rdata_length then
                    Some (qname_length, rdata_length, rr_type)
                  else
                    None
              | _ -> None
              end
        | None -> None
      else
        None
  | None -> None

val generated_compressed_answer_name_packet_subset_applicable :
  input:list FStar.UInt8.t ->
  Tot bool

let generated_compressed_answer_name_packet_subset_applicable input =
  match generated_compressed_answer_name_packet_fields input with
  | Some (qname_length, rdata_length, _) ->
      qname_length > 0 &&
      qname_length <= 255 &&
      rdata_length <= 65535 &&
      L.length input = 28 + qname_length + rdata_length
  | None -> false

val generated_compressed_name_rdata_packet_fields :
  input:list FStar.UInt8.t ->
  Tot (option (generated_dns_name_length * generated_dns_name_length * nat))

let generated_compressed_name_rdata_packet_fields input =
  match generated_uncompressed_question_answer_packet_fields input with
  | Some (qname_length, rr_name_length, rdata_length, rr_type, _, _, _) ->
      if (rr_type = 2 || rr_type = 5 || rr_type = 12) &&
         rdata_length = 2 &&
         L.length input = 28 + qname_length + rr_name_length then
        match parse_header_bytes input with
        | Some (_, after_header) ->
            begin match DNS.Name.parse_qname 128 after_header with
            | Some (_, question_tail) ->
                if L.length question_tail < 4 then
                  None
                else
                  let (_, after_question) = L.splitAt 4 question_tail in
                  begin match DNS.Name.parse_qname 128 after_question with
                  | Some (_, rr_tail) ->
                      begin match rr_tail with
                      | _rt_hi :: _rt_lo ::
                        _rc_hi :: _rc_lo ::
                        _ttl_0 :: _ttl_1 :: _ttl_2 :: _ttl_3 ::
                        _rdlen_hi :: _rdlen_lo ::
                        ptr_hi :: ptr_lo :: [] ->
                          if ptr_hi = 0xc0uy && ptr_lo = 0x0cuy then begin
                            assert (qname_length > 0);
                            assert (qname_length <= 255);
                            assert (rr_name_length > 0);
                            assert (rr_name_length <= 255);
                            let qn:generated_dns_name_length = qname_length in
                            let rn:generated_dns_name_length = rr_name_length in
                            Some (qn, rn, rr_type)
                          end
                          else
                            None
                      | _ -> None
                      end
                  | None -> None
                  end
            | None -> None
            end
        | None -> None
      else
        None
  | None -> None

val generated_compressed_name_rdata_packet_subset_applicable :
  input:list FStar.UInt8.t ->
  Tot bool

let generated_compressed_name_rdata_packet_subset_applicable input =
  match generated_compressed_name_rdata_packet_fields input with
  | Some (qname_length, rr_name_length, rr_type) ->
      qname_length > 0 &&
      qname_length <= 255 &&
      rr_name_length > 0 &&
      rr_name_length <= 255 &&
      (rr_type = 2 || rr_type = 5 || rr_type = 12) &&
      L.length input = 28 + qname_length + rr_name_length
  | None -> false

val generated_compressed_mx_packet_fields :
  input:list FStar.UInt8.t ->
  Tot (option (generated_dns_name_length * generated_dns_name_length))

let generated_compressed_mx_packet_fields input =
  match generated_uncompressed_question_answer_packet_fields input with
  | Some (qname_length, rr_name_length, rdata_length, rr_type, _, _, _) ->
      if rr_type = 15 &&
         rdata_length = 4 &&
         L.length input = 30 + qname_length + rr_name_length then
        match parse_header_bytes input with
        | Some (_, after_header) ->
            begin match DNS.Name.parse_qname 128 after_header with
            | Some (_, question_tail) ->
                if L.length question_tail < 4 then
                  None
                else
                  let (_, after_question) = L.splitAt 4 question_tail in
                  begin match DNS.Name.parse_qname 128 after_question with
                  | Some (_, rr_tail) ->
                      begin match rr_tail with
                      | _rt_hi :: _rt_lo ::
                        _rc_hi :: _rc_lo ::
                        _ttl_0 :: _ttl_1 :: _ttl_2 :: _ttl_3 ::
                        _rdlen_hi :: _rdlen_lo ::
                        _pref_hi :: _pref_lo ::
                        ptr_hi :: ptr_lo :: [] ->
                          if ptr_hi = 0xc0uy && ptr_lo = 0x0cuy then begin
                            assert (qname_length > 0);
                            assert (qname_length <= 255);
                            assert (rr_name_length > 0);
                            assert (rr_name_length <= 255);
                            let qn:generated_dns_name_length = qname_length in
                            let rn:generated_dns_name_length = rr_name_length in
                            Some (qn, rn)
                          end
                          else
                            None
                      | _ -> None
                      end
                  | None -> None
                  end
            | None -> None
            end
        | None -> None
      else
        None
  | None -> None

val generated_compressed_mx_packet_subset_applicable :
  input:list FStar.UInt8.t ->
  Tot bool

let generated_compressed_mx_packet_subset_applicable input =
  match generated_compressed_mx_packet_fields input with
  | Some (qname_length, rr_name_length) ->
      qname_length > 0 &&
      qname_length <= 255 &&
      rr_name_length > 0 &&
      rr_name_length <= 255 &&
      L.length input = 30 + qname_length + rr_name_length
  | None -> false

val generated_edns0_opt_additional_packet_fields :
  input:list FStar.UInt8.t ->
  Tot (option (option generated_dns_name_length * generated_dns_name_length * nat))

let generated_edns0_opt_additional_packet_fields input =
  let parse_opt_additional additional_input question_qname_length_opt =
    match DNS.Name.parse_qname 128 additional_input with
    | Some (rr_name, rr_tail) ->
        DNS.Name.lemma_parser_rejecting 128 additional_input;
        let rr_name_length_nat = DNS.Name.dns_name_length rr_name in
        assert (rr_name_length_nat > 0);
        assert (rr_name_length_nat <= 255);
        let rr_name_length:generated_dns_name_length = rr_name_length_nat in
        begin match rr_tail with
        | rt_hi :: rt_lo ::
          _rc_hi :: _rc_lo ::
          _ttl_0 :: _ttl_1 :: _ttl_2 :: _ttl_3 ::
          rdlen_hi :: rdlen_lo ::
          rdata_tail ->
            let rr_type = FStar.UInt16.v (u16_from_be rt_hi rt_lo) in
            let rdata_length:nat = FStar.UInt16.v (u16_from_be rdlen_hi rdlen_lo) in
            if rr_type = 41 && L.length rdata_tail = rdata_length then
              Some (question_qname_length_opt, rr_name_length, rdata_length)
            else
              None
        | _ -> None
        end
    | None -> None in
  match parse_header_bytes input with
  | Some (h, after_header) ->
      if FStar.UInt16.v h.ancount = 0 &&
         FStar.UInt16.v h.nscount = 0 &&
         FStar.UInt16.v h.arcount = 1 then
        if FStar.UInt16.v h.qdcount = 0 then
          parse_opt_additional after_header None
        else if FStar.UInt16.v h.qdcount = 1 then
          match DNS.Name.parse_qname 128 after_header with
          | Some (question_name, question_tail) ->
              DNS.Name.lemma_parser_rejecting 128 after_header;
              let question_qname_length_nat = DNS.Name.dns_name_length question_name in
              assert (question_qname_length_nat > 0);
              assert (question_qname_length_nat <= 255);
              let question_qname_length:generated_dns_name_length = question_qname_length_nat in
              if L.length question_tail < 4 then
                None
              else
                let (_, after_question) = L.splitAt 4 question_tail in
                parse_opt_additional after_question (Some question_qname_length)
          | None -> None
        else
          None
      else
        None
  | None -> None

val generated_edns0_opt_additional_packet_subset_applicable :
  input:list FStar.UInt8.t ->
  Tot bool

let generated_edns0_opt_additional_packet_subset_applicable input =
  match generated_edns0_opt_additional_packet_fields input with
  | Some (question_qname_length_opt, rr_name_length, option_payload_length) ->
      rr_name_length > 0 &&
      rr_name_length <= 255 &&
      option_payload_length <= 65535 &&
      (match question_qname_length_opt with
       | Some question_qname_length ->
           question_qname_length > 0 &&
           question_qname_length <= 255
       | None -> true)
  | None -> false

val validate_generated_uncompressed_question_subset_buffer :
  buffer:LowStar.Buffer.buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  bytes:list FStar.UInt8.t{
    L.length bytes == FStar.UInt32.v len /\
    generated_uncompressed_question_subset_applicable bytes == true
  } ->
  Stack bool
    (requires (fun h0 ->
      LowStar.Buffer.live h0 buffer /\
      FStar.UInt32.v len <= LowStar.Buffer.length buffer))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let validate_generated_uncompressed_question_subset_buffer buffer len bytes =
  assert (L.length bytes >= 17);
  assert (FStar.UInt32.v len >= 17);
  assert (12 <= LowStar.Buffer.length buffer);
  let qname_length_nat = generated_uncompressed_question_qname_length bytes in
  assert (qname_length_nat > 0);
  assert (qname_length_nat <= 255);
  let qname_length = FStar.UInt32.uint_to_t qname_length_nat in
  assert (FStar.UInt32.v qname_length == qname_length_nat);
  let question_len_nat = FStar.UInt32.v len - 12 in
  let question_len = FStar.UInt32.uint_to_t question_len_nat in
  assert (FStar.UInt32.v question_len == question_len_nat);
  let question = LowStar.Buffer.offset buffer 12ul in
  EPR.check_dns_uncompressed_question qname_length question question_len

val validate_generated_uncompressed_question_answer_packet_subset_buffer :
  buffer:LowStar.Buffer.buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  bytes:list FStar.UInt8.t{
    L.length bytes == FStar.UInt32.v len /\
    generated_uncompressed_question_answer_packet_subset_applicable bytes == true
  } ->
  Stack bool
    (requires (fun h0 ->
      LowStar.Buffer.live h0 buffer /\
      FStar.UInt32.v len <= LowStar.Buffer.length buffer))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let validate_generated_uncompressed_question_answer_packet_subset_buffer buffer len bytes =
  match generated_uncompressed_question_answer_packet_fields bytes with
  | Some (qname_length_nat, rr_name_length_nat, rdata_length_nat, rr_type_nat, _, rdata_name_length_opt, soa_rname_length_opt) ->
      assert (qname_length_nat > 0);
      assert (qname_length_nat <= 255);
      assert (rr_name_length_nat > 0);
      assert (rr_name_length_nat <= 255);
      assert (rdata_length_nat <= 65535);
      let qname_length = FStar.UInt32.uint_to_t qname_length_nat in
      assert (FStar.UInt32.v qname_length == qname_length_nat);
      let rr_name_length = FStar.UInt32.uint_to_t rr_name_length_nat in
      assert (FStar.UInt32.v rr_name_length == rr_name_length_nat);
      let rdata_length = FStar.UInt32.uint_to_t rdata_length_nat in
      assert (FStar.UInt32.v rdata_length == rdata_length_nat);
      if rr_type_nat = 1 then
        EPR.check_dns_uncompressed_question_a_answer_packet
          qname_length
          rr_name_length
          buffer
          len
      else if rr_type_nat = 28 then
        EPR.check_dns_uncompressed_question_aaaa_answer_packet
          qname_length
          rr_name_length
          buffer
          len
      else if rr_type_nat = 2 || rr_type_nat = 5 || rr_type_nat = 12 then
        match rdata_name_length_opt with
        | Some rdata_name_length_nat ->
            assert (rdata_name_length_nat > 0);
            assert (rdata_name_length_nat <= 255);
            let rdata_name_length = FStar.UInt32.uint_to_t rdata_name_length_nat in
            assert (FStar.UInt32.v rdata_name_length == rdata_name_length_nat);
            let expected_rtype = FStar.UInt32.uint_to_t rr_type_nat in
            assert (FStar.UInt32.v expected_rtype == rr_type_nat);
            EPR.check_dns_uncompressed_question_name_rdata_answer_packet
              qname_length
              rr_name_length
              rdata_name_length
              expected_rtype
              buffer
              len
        | None ->
            false
      else if rr_type_nat = 15 then
        match rdata_name_length_opt with
        | Some exchange_name_length_nat ->
            assert (exchange_name_length_nat > 0);
            assert (exchange_name_length_nat <= 255);
            let exchange_name_length = FStar.UInt32.uint_to_t exchange_name_length_nat in
            assert (FStar.UInt32.v exchange_name_length == exchange_name_length_nat);
            EPR.check_dns_uncompressed_question_mx_answer_packet
              qname_length
              rr_name_length
              exchange_name_length
              buffer
              len
        | None ->
            false
      else if rr_type_nat = 6 then
        match rdata_name_length_opt, soa_rname_length_opt with
        | Some mname_length_nat, Some rname_length_nat ->
            assert (mname_length_nat > 0);
            assert (mname_length_nat <= 255);
            assert (rname_length_nat > 0);
            assert (rname_length_nat <= 255);
            let mname_length = FStar.UInt32.uint_to_t mname_length_nat in
            assert (FStar.UInt32.v mname_length == mname_length_nat);
            let rname_length = FStar.UInt32.uint_to_t rname_length_nat in
            assert (FStar.UInt32.v rname_length == rname_length_nat);
            EPR.check_dns_uncompressed_question_soa_answer_packet
              qname_length
              rr_name_length
              mname_length
              rname_length
              buffer
              len
        | _, _ ->
            false
      else if rr_type_nat = 33 then
        match rdata_name_length_opt with
        | Some target_name_length_nat ->
            assert (target_name_length_nat > 0);
            assert (target_name_length_nat <= 255);
            let target_name_length = FStar.UInt32.uint_to_t target_name_length_nat in
            assert (FStar.UInt32.v target_name_length == target_name_length_nat);
            EPR.check_dns_uncompressed_question_srv_answer_packet
              qname_length
              rr_name_length
              target_name_length
              buffer
              len
        | None ->
            false
      else if rr_type_nat = 16 then
        EPR.check_dns_uncompressed_question_txt_answer_packet
          qname_length
          rr_name_length
          rdata_length
          buffer
          len
      else
        EPR.check_dns_uncompressed_question_answer_packet
          qname_length
          rr_name_length
          rdata_length
          buffer
          len
  | None ->
      false

val validate_generated_compressed_answer_name_packet_subset_buffer :
  buffer:LowStar.Buffer.buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  bytes:list FStar.UInt8.t{
    L.length bytes == FStar.UInt32.v len /\
    generated_compressed_answer_name_packet_subset_applicable bytes == true
  } ->
  Stack bool
    (requires (fun h0 ->
      LowStar.Buffer.live h0 buffer /\
      FStar.UInt32.v len <= LowStar.Buffer.length buffer))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let validate_generated_compressed_answer_name_packet_subset_buffer buffer len bytes =
  match generated_compressed_answer_name_packet_fields bytes with
  | Some (qname_length_nat, rdata_length_nat, _) ->
      assert (qname_length_nat > 0);
      assert (qname_length_nat <= 255);
      assert (rdata_length_nat <= 65535);
      let qname_length = FStar.UInt32.uint_to_t qname_length_nat in
      assert (FStar.UInt32.v qname_length == qname_length_nat);
      let rdata_length = FStar.UInt32.uint_to_t rdata_length_nat in
      assert (FStar.UInt32.v rdata_length == rdata_length_nat);
      EPR.check_dns_uncompressed_question_compressed_answer_name_packet
        qname_length
        rdata_length
        buffer
        len
  | None ->
      false

val validate_generated_compressed_name_rdata_packet_subset_buffer :
  buffer:LowStar.Buffer.buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  bytes:list FStar.UInt8.t{
    L.length bytes == FStar.UInt32.v len /\
    generated_compressed_name_rdata_packet_subset_applicable bytes == true
  } ->
  Stack bool
    (requires (fun h0 ->
      LowStar.Buffer.live h0 buffer /\
      FStar.UInt32.v len <= LowStar.Buffer.length buffer))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let validate_generated_compressed_name_rdata_packet_subset_buffer buffer len bytes =
  match generated_compressed_name_rdata_packet_fields bytes with
  | Some (qname_length_nat, rr_name_length_nat, rr_type_nat) ->
      assert (qname_length_nat > 0);
      assert (qname_length_nat <= 255);
      assert (rr_name_length_nat > 0);
      assert (rr_name_length_nat <= 255);
      let qname_length = FStar.UInt32.uint_to_t qname_length_nat in
      assert (FStar.UInt32.v qname_length == qname_length_nat);
      let rr_name_length = FStar.UInt32.uint_to_t rr_name_length_nat in
      assert (FStar.UInt32.v rr_name_length == rr_name_length_nat);
      let expected_rtype = FStar.UInt32.uint_to_t rr_type_nat in
      assert (FStar.UInt32.v expected_rtype == rr_type_nat);
      EPR.check_dns_uncompressed_question_compressed_name_rdata_answer_packet
        qname_length
        rr_name_length
        expected_rtype
        buffer
        len
  | None ->
      false

val validate_generated_compressed_mx_packet_subset_buffer :
  buffer:LowStar.Buffer.buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  bytes:list FStar.UInt8.t{
    L.length bytes == FStar.UInt32.v len /\
    generated_compressed_mx_packet_subset_applicable bytes == true
  } ->
  Stack bool
    (requires (fun h0 ->
      LowStar.Buffer.live h0 buffer /\
      FStar.UInt32.v len <= LowStar.Buffer.length buffer))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let validate_generated_compressed_mx_packet_subset_buffer buffer len bytes =
  match generated_compressed_mx_packet_fields bytes with
  | Some (qname_length_nat, rr_name_length_nat) ->
      assert (qname_length_nat > 0);
      assert (qname_length_nat <= 255);
      assert (rr_name_length_nat > 0);
      assert (rr_name_length_nat <= 255);
      let qname_length = FStar.UInt32.uint_to_t qname_length_nat in
      assert (FStar.UInt32.v qname_length == qname_length_nat);
      let rr_name_length = FStar.UInt32.uint_to_t rr_name_length_nat in
      assert (FStar.UInt32.v rr_name_length == rr_name_length_nat);
      EPR.check_dns_uncompressed_question_compressed_mx_answer_packet
        qname_length
        rr_name_length
        buffer
        len
  | None ->
      false

val validate_generated_edns0_opt_additional_packet_subset_buffer :
  buffer:LowStar.Buffer.buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  bytes:list FStar.UInt8.t{
    L.length bytes == FStar.UInt32.v len /\
    generated_edns0_opt_additional_packet_subset_applicable bytes == true
  } ->
  Stack bool
    (requires (fun h0 ->
      LowStar.Buffer.live h0 buffer /\
      FStar.UInt32.v len <= LowStar.Buffer.length buffer))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let validate_generated_edns0_opt_additional_packet_subset_buffer buffer len bytes =
  match generated_edns0_opt_additional_packet_fields bytes with
  | Some (question_qname_length_opt, _, option_payload_length_nat) ->
      assert (option_payload_length_nat <= 65535);
      let option_payload_length = FStar.UInt32.uint_to_t option_payload_length_nat in
      assert (FStar.UInt32.v option_payload_length == option_payload_length_nat);
      begin match question_qname_length_opt with
      | Some question_qname_length_nat ->
          assert (question_qname_length_nat > 0);
          assert (question_qname_length_nat <= 255);
          let question_qname_length = FStar.UInt32.uint_to_t question_qname_length_nat in
          assert (FStar.UInt32.v question_qname_length == question_qname_length_nat);
          EPR.check_dns_uncompressed_question_opt_additional_packet
            question_qname_length
            option_payload_length
            buffer
            len
      | None ->
          EPR.check_dns_opt_additional_packet
            option_payload_length
            buffer
            len
      end
  | None ->
      false

val validate_generated_subset_gate_buffer :
  buffer:LowStar.Buffer.buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  bytes:list FStar.UInt8.t{L.length bytes == FStar.UInt32.v len} ->
  Stack bool
    (requires (fun h0 ->
      LowStar.Buffer.live h0 buffer /\
      FStar.UInt32.v len <= LowStar.Buffer.length buffer))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let validate_generated_subset_gate_buffer buffer len bytes =
  if generated_edns0_opt_additional_packet_subset_applicable bytes then
    validate_generated_edns0_opt_additional_packet_subset_buffer buffer len bytes
  else if generated_compressed_answer_name_packet_subset_applicable bytes then
    validate_generated_compressed_answer_name_packet_subset_buffer buffer len bytes
  else if generated_compressed_name_rdata_packet_subset_applicable bytes then
    validate_generated_compressed_name_rdata_packet_subset_buffer buffer len bytes
  else if generated_compressed_mx_packet_subset_applicable bytes then
    validate_generated_compressed_mx_packet_subset_buffer buffer len bytes
  else if generated_uncompressed_question_answer_packet_subset_applicable bytes then
    validate_generated_uncompressed_question_answer_packet_subset_buffer buffer len bytes
  else if generated_uncompressed_question_subset_applicable bytes then
    validate_generated_uncompressed_question_subset_buffer buffer len bytes
  else
    true

val read_buffer_range :
  buffer:LowStar.Buffer.buffer FStar.UInt8.t ->
  pos:nat ->
  remaining:nat ->
  Stack (bytes:list FStar.UInt8.t{L.length bytes == remaining})
    (requires (fun h0 ->
      LowStar.Buffer.live h0 buffer /\
      pos + remaining <= LowStar.Buffer.length buffer /\
      pos + remaining <= 4294967295))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))
    (decreases remaining)

let rec read_buffer_range buffer pos remaining =
  if remaining = 0 then
    []
  else
    let idx = FStar.UInt32.uint_to_t pos in
    assert (FStar.UInt32.v idx == pos);
    let b = LowStar.Buffer.index buffer idx in
    let rest = read_buffer_range buffer (pos + 1) (remaining - 1) in
    b :: rest

let parse_dns_packet_buffer buffer len =
  let bytes = read_buffer_range buffer 0 (FStar.UInt32.v len) in
  let generated_subset_ok = validate_generated_subset_gate_buffer buffer len bytes in
  if generated_subset_ok then
    parse_dns_packet_bytes bytes
  else
    None

val lemma_read_buffer_range_length :
  buffer:LowStar.Buffer.buffer FStar.UInt8.t ->
  pos:nat ->
  remaining:nat ->
  Stack unit
    (requires (fun h0 ->
      LowStar.Buffer.live h0 buffer /\
      pos + remaining <= LowStar.Buffer.length buffer /\
      pos + remaining <= 4294967295))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let lemma_read_buffer_range_length buffer pos remaining =
  let _bytes = read_buffer_range buffer pos remaining in
  ()

val lemma_parse_dns_packet_buffer_reads_len :
  buffer:LowStar.Buffer.buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack unit
    (requires (fun h0 ->
      LowStar.Buffer.live h0 buffer /\
      FStar.UInt32.v len <= LowStar.Buffer.length buffer))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let lemma_parse_dns_packet_buffer_reads_len buffer len =
  let bytes = read_buffer_range buffer 0 (FStar.UInt32.v len) in
  assert (L.length bytes == FStar.UInt32.v len);
  ()

val lemma_parse_dns_packet_buffer_safe_prefix :
  buffer:LowStar.Buffer.buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack unit
    (requires (fun h0 ->
      LowStar.Buffer.live h0 buffer /\
      FStar.UInt32.v len <= LowStar.Buffer.length buffer))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let lemma_parse_dns_packet_buffer_safe_prefix buffer len =
  let _res = parse_dns_packet_buffer buffer len in
  ()

(* --- Validation Proofs --- *)

val flags_to_uint16 (f: dns_flags) : FStar.UInt16.t
let flags_to_uint16 f =
  let qr     = if f.qr then 32768 else 0 in
  let opcode = Prims.op_Multiply (FStar.UInt16.v f.opcode) 2048 in
  let aa     = if f.aa then 1024 else 0 in
  let tc     = if f.tc then 512 else 0 in
  let rd     = if f.rd then 256 else 0 in
  let ra     = if f.ra then 128 else 0 in
  let z      = if f.z  then 64 else 0 in
  let ad     = if f.ad then 32 else 0 in
  let cd     = if f.cd then 16 else 0 in
  FStar.UInt16.uint_to_t (qr + opcode + aa + tc + rd + ra + z + ad + cd + FStar.UInt16.v f.rcode)

val lemma_flags_invertible : f_in:FStar.UInt16.t -> 
  Lemma (ensures (flags_to_uint16 (uint16_to_flags f_in) == f_in))
let lemma_flags_invertible f_in =
  let raw = FStar.UInt16.v f_in in
  FStar.Math.Lemmas.euclidean_division_definition raw 32768;
  FStar.Math.Lemmas.modulo_range_lemma raw 32768;
  FStar.Math.Lemmas.modulo_division_lemma raw 2048 16;
  FStar.Math.Lemmas.modulo_modulo_lemma raw 2048 16;
  FStar.Math.Lemmas.euclidean_division_definition (raw % 32768) 2048;
  FStar.Math.Lemmas.modulo_division_lemma raw 1024 2;
  FStar.Math.Lemmas.modulo_modulo_lemma raw 1024 2;
  FStar.Math.Lemmas.euclidean_division_definition (raw % 2048) 1024;
  FStar.Math.Lemmas.modulo_division_lemma raw 512 2;
  FStar.Math.Lemmas.modulo_modulo_lemma raw 512 2;
  FStar.Math.Lemmas.euclidean_division_definition (raw % 1024) 512;
  FStar.Math.Lemmas.modulo_division_lemma raw 256 2;
  FStar.Math.Lemmas.modulo_modulo_lemma raw 256 2;
  FStar.Math.Lemmas.euclidean_division_definition (raw % 512) 256;
  FStar.Math.Lemmas.modulo_division_lemma raw 128 2;
  FStar.Math.Lemmas.modulo_modulo_lemma raw 128 2;
  FStar.Math.Lemmas.euclidean_division_definition (raw % 256) 128;
  FStar.Math.Lemmas.modulo_division_lemma raw 64 2;
  FStar.Math.Lemmas.modulo_modulo_lemma raw 64 2;
  FStar.Math.Lemmas.euclidean_division_definition (raw % 128) 64;
  FStar.Math.Lemmas.modulo_division_lemma raw 32 2;
  FStar.Math.Lemmas.modulo_modulo_lemma raw 32 2;
  FStar.Math.Lemmas.euclidean_division_definition (raw % 64) 32;
  FStar.Math.Lemmas.modulo_division_lemma raw 16 2;
  FStar.Math.Lemmas.modulo_modulo_lemma raw 16 2;
  FStar.Math.Lemmas.euclidean_division_definition (raw % 32) 16;
  assert (raw / 32768 == 0 \/ raw / 32768 == 1);
  assert ((if raw / 32768 = 1 then 32768 else 0) == Prims.op_Multiply (raw / 32768) 32768);
  assert (FStar.UInt16.v (flags_to_uint16 (uint16_to_flags f_in)) == raw);
  FStar.UInt16.v_inj (flags_to_uint16 (uint16_to_flags f_in)) f_in

let has_dns_header_length (len:FStar.UInt32.t) : bool =
  FStar.UInt32.v len >= 12

val theorem_header_length_guard : len:FStar.UInt32.t ->
  Lemma (requires (has_dns_header_length len == true))
        (ensures (FStar.UInt32.v len >= 12)) 
let theorem_header_length_guard len =
  ()

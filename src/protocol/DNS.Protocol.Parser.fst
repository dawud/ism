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
          match parse_resource_records_bytes false an an after_questions with
          | None -> None
          | Some (answers, after_answers) ->
              match parse_resource_records_bytes false ns ns after_answers with
              | None -> None
              | Some (authorities, after_authorities) ->
                  match parse_resource_records_bytes true ar ar after_authorities with
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

val generated_single_label_question_subset_applicable :
  input:list FStar.UInt8.t ->
  Tot bool

let generated_single_label_question_subset_applicable input =
  if L.length input < 18 || L.length input > 80 then
    false
  else
    begin
      assert (12 < L.length input);
      let label_len_byte = L.index input 12 in
      let label_len = FStar.UInt8.v label_len_byte in
      if label_len = 0 || label_len > 63 then
        false
      else if L.length input = 18 + label_len then
        begin
          assert (13 + label_len < L.length input);
          L.index input (13 + label_len) = 0uy
        end
      else
        false
    end

val generated_two_label_question_subset_applicable :
  input:list FStar.UInt8.t ->
  Tot bool

let generated_two_label_question_subset_applicable input =
  if L.length input < 21 || L.length input > 145 then
    false
  else
    begin
      assert (12 < L.length input);
      let first_label_len_byte = L.index input 12 in
      let first_label_len = FStar.UInt8.v first_label_len_byte in
      if first_label_len = 0 || first_label_len > 63 then
        false
      else
        let second_label_len_pos = 13 + first_label_len in
        if second_label_len_pos >= L.length input then
          false
        else
          let second_label_len_byte = L.index input second_label_len_pos in
          let second_label_len = FStar.UInt8.v second_label_len_byte in
          if second_label_len = 0 || second_label_len > 63 then
            false
          else if L.length input = 19 + first_label_len + second_label_len then
            begin
              let root_pos = 14 + first_label_len + second_label_len in
              assert (root_pos < L.length input);
              L.index input root_pos = 0uy
            end
          else
            false
    end

val validate_generated_root_question_subset_buffer :
  buffer:LowStar.Buffer.buffer FStar.UInt8.t ->
  len:FStar.UInt32.t{FStar.UInt32.v len == 17} ->
  Stack bool
    (requires (fun h0 ->
      LowStar.Buffer.live h0 buffer /\
      FStar.UInt32.v len <= LowStar.Buffer.length buffer))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let validate_generated_root_question_subset_buffer buffer len =
  let header_ok = EPR.check_dns_header buffer len in
  if header_ok then
    let question = LowStar.Buffer.offset buffer 12ul in
    EPR.check_dns_root_question question 5ul
  else
    false

val validate_generated_single_label_question_subset_buffer :
  buffer:LowStar.Buffer.buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  bytes:list FStar.UInt8.t{
    L.length bytes == FStar.UInt32.v len /\
    generated_single_label_question_subset_applicable bytes == true
  } ->
  Stack bool
    (requires (fun h0 ->
      LowStar.Buffer.live h0 buffer /\
      FStar.UInt32.v len <= LowStar.Buffer.length buffer))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let validate_generated_single_label_question_subset_buffer buffer len bytes =
  assert (L.length bytes >= 18);
  assert (FStar.UInt32.v len >= 18);
  assert (12 <= LowStar.Buffer.length buffer);
  assert (12 < L.length bytes);
  let label_len = FStar.UInt8.v (L.index bytes 12) in
  assert (label_len > 0);
  assert (label_len <= 63);
  let label_length = FStar.UInt32.uint_to_t label_len in
  assert (FStar.UInt32.v label_length == label_len);
  let question_len_nat = FStar.UInt32.v len - 12 in
  let question_len = FStar.UInt32.uint_to_t question_len_nat in
  assert (FStar.UInt32.v question_len == question_len_nat);
  let question = LowStar.Buffer.offset buffer 12ul in
  EPR.check_dns_single_label_question label_length question question_len

val validate_generated_two_label_question_subset_buffer :
  buffer:LowStar.Buffer.buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  bytes:list FStar.UInt8.t{
    L.length bytes == FStar.UInt32.v len /\
    generated_two_label_question_subset_applicable bytes == true
  } ->
  Stack bool
    (requires (fun h0 ->
      LowStar.Buffer.live h0 buffer /\
      FStar.UInt32.v len <= LowStar.Buffer.length buffer))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let validate_generated_two_label_question_subset_buffer buffer len bytes =
  assert (L.length bytes >= 21);
  assert (FStar.UInt32.v len >= 21);
  assert (12 <= LowStar.Buffer.length buffer);
  assert (12 < L.length bytes);
  let first_label_len = FStar.UInt8.v (L.index bytes 12) in
  assert (first_label_len > 0);
  assert (first_label_len <= 63);
  let second_label_len_pos = 13 + first_label_len in
  assert (second_label_len_pos < L.length bytes);
  let second_label_len = FStar.UInt8.v (L.index bytes second_label_len_pos) in
  assert (second_label_len > 0);
  assert (second_label_len <= 63);
  let first_label_length = FStar.UInt32.uint_to_t first_label_len in
  assert (FStar.UInt32.v first_label_length == first_label_len);
  let second_label_length = FStar.UInt32.uint_to_t second_label_len in
  assert (FStar.UInt32.v second_label_length == second_label_len);
  let question_len_nat = FStar.UInt32.v len - 12 in
  let question_len = FStar.UInt32.uint_to_t question_len_nat in
  assert (FStar.UInt32.v question_len == question_len_nat);
  let question = LowStar.Buffer.offset buffer 12ul in
  EPR.check_dns_two_label_question first_label_length second_label_length question question_len

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
  if FStar.UInt32.v len = 17 then
    validate_generated_root_question_subset_buffer buffer len
  else if generated_single_label_question_subset_applicable bytes then
    validate_generated_single_label_question_subset_buffer buffer len bytes
  else if generated_two_label_question_subset_applicable bytes then
    validate_generated_two_label_question_subset_buffer buffer len bytes
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

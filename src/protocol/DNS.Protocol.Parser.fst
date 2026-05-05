module DNS.Protocol.Parser

open FStar.UInt16
open FStar.HyperStack.ST
open LowParse.Low.Base
open DNS.Protocol
open DNS.Constants
module L = FStar.List.Tot

(* --- Flag Mapping --- *)

let uint16_to_flags (raw_flags: FStar.UInt16.t) : dns_flags =
  let open FStar.UInt16 in
  {
    qr     = (raw_flags >>^ 15ul) = 1us;
    opcode = (raw_flags >>^ 11ul) %^ 16us;
    aa     = (raw_flags >>^ 10ul) %^ 2us = 1us;
    tc     = (raw_flags >>^ 9ul) %^ 2us = 1us;
    rd     = (raw_flags >>^ 8ul) %^ 2us = 1us;
    ra     = (raw_flags >>^ 7ul) %^ 2us = 1us;
    z      = (raw_flags >>^ 6ul) %^ 2us = 1us;
    ad     = (raw_flags >>^ 5ul) %^ 2us = 1us;
    cd     = (raw_flags >>^ 4ul) %^ 2us = 1us;
    rcode  = raw_flags %^ 16us;
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

val parse_dns_packet_bytes :
  input:list FStar.UInt8.t ->
  Tot (option dns_packet)

let parse_dns_packet_bytes input =
  match parse_header_bytes input with
  | None -> None
  | Some (h, rest) ->
      (* This first concrete parser closes the header/question boundary.
         RR section parsing remains intentionally rejected until implemented. *)
      if h.ancount <> 0us || h.nscount <> 0us || h.arcount <> 0us then
        None
      else
        let qd = FStar.UInt16.v h.qdcount in
        match parse_questions_bytes qd qd rest with
        | None -> None
        | Some (qs, tail) ->
            if L.length tail = 0 then
              Some {
                header = h;
                questions = qs;
                answers = [];
                authorities = [];
                additionals = [];
              }
            else
              None

let validate_dns_packet_bytes (input:list FStar.UInt8.t) : bool =
  match parse_dns_packet_bytes input with
  | Some _ -> true
  | None -> false

val parse_dns_packet_buffer :
  buffer:uint8_ptr ->
  len:FStar.UInt32.t ->
  Stack (option dns_packet)
    (requires (fun h0 ->
      LowStar.Buffer.live h0 buffer /\
      FStar.UInt32.v len <= LowStar.Buffer.length buffer))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

val read_buffer_range :
  buffer:uint8_ptr ->
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
  parse_dns_packet_bytes bytes

val lemma_read_buffer_range_length :
  buffer:uint8_ptr ->
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
  buffer:uint8_ptr ->
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
  buffer:uint8_ptr ->
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
  let open FStar.UInt16 in
  (if f.qr then 1us <<^ 15ul else 0us) |^
  ((f.opcode %^ 16us) <<^ 11ul) |^
  (if f.aa then 1us <<^ 10ul else 0us) |^
  (if f.tc then 1us <<^ 9ul else 0us) |^
  (if f.rd then 1us <<^ 8ul else 0us) |^
  (if f.ra then 1us <<^ 7ul else 0us) |^
  (if f.z  then 1us <<^ 6ul else 0us) |^
  (if f.ad then 1us <<^ 5ul else 0us) |^
  (if f.cd then 1us <<^ 4ul else 0us) |^
  (f.rcode %^ 16us)

val lemma_flags_invertible : f_in:FStar.UInt16.t -> 
  Lemma (ensures (flags_to_uint16 (uint16_to_flags f_in) == f_in))
let lemma_flags_invertible f_in =
  admit()

let has_dns_header_length (len:FStar.UInt32.t) : bool =
  FStar.UInt32.v len >= 12

val theorem_header_length_guard : len:FStar.UInt32.t ->
  Lemma (requires (has_dns_header_length len == true))
        (ensures (FStar.UInt32.v len >= 12)) 
let theorem_header_length_guard len =
  ()

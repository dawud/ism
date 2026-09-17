module DNS.Name

open FStar.UInt8
module L = FStar.List.Tot
module LP = FStar.List.Tot.Properties
module LPP = FStar.List.Pure.Properties

(* A label is a list of bytes with length between 1 and 63 *)
type label = l:list FStar.UInt8.t{L.length l >= 1 && L.length l <= 63}

(* A QNAME is logically a list of labels. 
   Termination is guaranteed because the list is finite. *)
type qname = list label

(* DNS names keep wire/presentation order and spelling. Only comparisons fold
   ASCII letters; arbitrary label octets are preserved. *)
let fold_ascii (b:FStar.UInt8.t) : FStar.UInt8.t =
  if FStar.UInt8.v b >= 65 && FStar.UInt8.v b <= 90 then
    FStar.UInt8.uint_to_t (Prims.op_Addition (FStar.UInt8.v b) 32)
  else b

let rec canonical_bytes (bs:list FStar.UInt8.t)
  : Tot (out:list FStar.UInt8.t{L.length out == L.length bs}) =
  match bs with
  | [] -> []
  | b :: rest -> fold_ascii b :: canonical_bytes rest

let canonical_label (l:label) : label = canonical_bytes l
let rec canonical_name (name:qname) : Tot qname =
  match name with
  | [] -> []
  | l :: rest -> canonical_label l :: canonical_name rest

let label_eq (a:label) (b:label) : bool = canonical_label a = canonical_label b
let qname_eq (a:qname) (b:qname) : bool = canonical_name a = canonical_name b

let lemma_name_equality_reflexive (a:qname) : Lemma (qname_eq a a) = ()
let lemma_name_equality_symmetric (a:qname) (b:qname)
  : Lemma (qname_eq a b == qname_eq b a) = ()
let lemma_name_equality_transitive (a:qname) (b:qname) (c:qname)
  : Lemma (requires (qname_eq a b /\ qname_eq b c))
          (ensures (qname_eq a c)) = ()

(* Traversal keys are deliberately distinct from names used on the wire. *)
type tree_key = | TreeKey of qname
let name_to_tree_key (name:qname) : tree_key = TreeKey (L.rev name)

(* Helper to check if a byte is a pointer (starts with 11) *)
let is_pointer (b: FStar.UInt8.t) : bool =
  FStar.UInt8.v b >= 192

let pointer_offset (hi:FStar.UInt8.t{FStar.UInt8.v hi >= 192}) (lo:FStar.UInt8.t) : nat =
  let hi_part = Prims.op_Subtraction (FStar.UInt8.v hi) 192 in
  Prims.op_Addition (Prims.op_Multiply hi_part 256) (FStar.UInt8.v lo)

val suffix_at :
  offset:nat ->
  input:list FStar.UInt8.t ->
  Tot (option (list FStar.UInt8.t)) (decreases offset)

let rec suffix_at offset input =
  if offset = 0 then
    Some input
  else
    match input with
    | [] -> None
    | _ :: tl -> suffix_at (offset - 1) tl

let take_label (len:nat{len >= 1 && len <= 63}) (rest:list FStar.UInt8.t{L.length rest >= len})
  : (lbl:label{L.length lbl == len} * list FStar.UInt8.t)
  =
  let (l_list, next_input) = L.splitAt len rest in
  LPP.splitAt_length len rest;
  (l_list, next_input)

let rec dns_name_length (l: qname) : nat =
  match l with
  | [] -> 1
  | hd :: tl -> L.length hd + 1 + dns_name_length tl

type parsed_qname (remaining:nat) = (name:qname{dns_name_length name <= remaining} * list FStar.UInt8.t)

(* EverParse-style combinator for a compressed name *)
val parse_qname_bounded (fuel: nat) (remaining:nat) (input: list FStar.UInt8.t) :
  Tot (option (parsed_qname remaining)) (decreases fuel)

let rec parse_qname_bounded fuel remaining input =
  if fuel = 0 then 
    None (* Pointer loop or excessive recursion detected *)
  else
    match input with
    | [] -> None
    | b :: rest ->
        if b = 0uy then
          if remaining >= 1 then Some ([], rest) else None (* End of name *)
        else if is_pointer b then
          None 
        else
          (* Normal label: b is the length *)
          let len = FStar.UInt8.v b in
          if len < 1 || len > 63 then
            None 
          else if L.length rest < len then
            None
          else if len + 1 >= remaining then
            None
          else
            let (l, next_input) = take_label len rest in
            match parse_qname_bounded (fuel - 1) (remaining - (len + 1)) next_input with
            | Some (tl, final_input) -> Some (l :: tl, final_input)
            | None -> None

val parse_qname (fuel: nat) (input: list FStar.UInt8.t) :
  Tot (option (qname * list FStar.UInt8.t)) (decreases fuel)

let parse_qname fuel input =
  match parse_qname_bounded fuel 255 input with
  | Some (name, rest) -> Some (name, rest)
  | None -> None

(* A structural pass records only label/root/pointer boundaries reached while
   walking DNS name fields. It never searches for name-shaped bytes in payloads.
   Pointer resolution below checks membership and strictly decreases its limit. *)
let wire_u16 (hi:FStar.UInt8.t) (lo:FStar.UInt8.t) : nat =
  Prims.op_Addition (Prims.op_Multiply (FStar.UInt8.v hi) 256) (FStar.UInt8.v lo)

let rec scan_wire_name (fuel:nat) (pos:nat) (input:list FStar.UInt8.t)
  : Tot (option (list nat * nat * list FStar.UInt8.t)) (decreases fuel) =
  if fuel = 0 then None else
  match input with
  | [] -> None
  | b :: rest ->
      if b = 0uy then Some ([pos], pos + 1, rest)
      else if is_pointer b then
        (match rest with
         | _ :: tail -> Some ([pos], pos + 2, tail)
         | _ -> None)
      else if FStar.UInt8.v b > 63 || L.length rest < FStar.UInt8.v b then None
      else
        let (_, tail) = L.splitAt (FStar.UInt8.v b) rest in
        match scan_wire_name (fuel - 1) (pos + 1 + FStar.UInt8.v b) tail with
        | Some (offsets, next, remaining) -> Some (pos :: offsets, next, remaining)
        | None -> None

let rdata_name_offsets (rtype:nat) (pos:nat) (payload:list FStar.UInt8.t) : list nat =
  let start = if rtype = 15 then 2 else if rtype = 33 then 6 else 0 in
  if rtype = 2 || rtype = 5 || rtype = 12 || rtype = 15 || rtype = 33 || rtype = 6 then
    match suffix_at start payload with
    | None -> []
    | Some name_bytes ->
        (match scan_wire_name 128 (pos + start) name_bytes with
         | None -> []
         | Some (first, next, rest) ->
             if rtype = 6 then
               (match scan_wire_name 128 next rest with
                | Some (second, _, timers) ->
                    if L.length timers = 20 then L.append first second else []
                | None -> [])
             else if L.length rest = 0 then first else [])
  else []

let rec scan_wire_records (count:nat) (pos:nat) (input:list FStar.UInt8.t)
  : Tot (option (list nat)) (decreases count) =
  if count = 0 then (if L.length input = 0 then Some [] else None) else
  match scan_wire_name 128 pos input with
  | None -> None
  | Some (owner, header_pos, rest) ->
      (match rest with
       | th :: tl :: _ :: _ :: _ :: _ :: _ :: _ :: lh :: ll :: body ->
           let size = wire_u16 lh ll in
           if L.length body < size then None else
           let (payload, tail) = L.splitAt size body in
           let data_pos = header_pos + 10 in
           (match scan_wire_records (count - 1) (data_pos + size) tail with
            | None -> None
            | Some later -> Some (L.append owner
                (L.append (rdata_name_offsets (wire_u16 th tl) data_pos payload) later)))
       | _ -> None)

let rec scan_wire_questions (count:nat) (records:nat) (pos:nat) (input:list FStar.UInt8.t)
  : Tot (option (list nat)) (decreases count) =
  if count = 0 then scan_wire_records records pos input else
  match scan_wire_name 128 pos input with
  | None -> None
  | Some (offsets, next, rest) ->
      (match rest with
       | _ :: _ :: _ :: _ :: tail ->
           (match scan_wire_questions (count - 1) records (next + 4) tail with
            | Some later -> Some (L.append offsets later)
            | None -> None)
       | _ -> None)

let message_name_offsets (original:list FStar.UInt8.t) : list nat =
  match original with
  | _ :: _ :: _ :: _ :: qh :: ql :: ah :: al :: nh :: nl :: rh :: rl :: rest ->
      (match scan_wire_questions (wire_u16 qh ql)
          (wire_u16 ah al + wire_u16 nh nl + wire_u16 rh rl) 12 rest with
       | Some offsets -> offsets
       | None -> [])
  | _ -> []

let valid_pointer_target (known:list nat) (limit:nat) (target:nat) : bool =
  target >= 12 && target < limit && L.mem target known

let lemma_pointer_target_is_name (known:list nat) (limit:nat) (target:nat)
  : Lemma (requires (valid_pointer_target known limit target))
          (ensures (target >= 12 /\ target < limit /\ L.mem target known)) = ()

val parse_qname_compressed_bounded :
  fuel:nat ->
  remaining:nat ->
  original:list FStar.UInt8.t ->
  known_offsets:list nat ->
  pointer_limit:nat ->
  input:list FStar.UInt8.t ->
  Tot (option (parsed_qname remaining)) (decreases fuel)

let rec parse_qname_compressed_bounded fuel remaining original known_offsets pointer_limit input =
  if fuel = 0 then
    None
  else
    match input with
    | [] -> None
    | b :: rest ->
        if b = 0uy then
          if remaining >= 1 then Some ([], rest) else None
        else if is_pointer b then
          begin match rest with
          | lo :: tail ->
              let offset = pointer_offset b lo in
              if not (valid_pointer_target known_offsets pointer_limit offset) then
                None
              else
                begin match suffix_at offset original with
                | None -> None
                | Some target ->
                    begin match parse_qname_compressed_bounded
                            (fuel - 1)
                            remaining
                            original
                            known_offsets
                            offset
                            target with
                    | Some (name, _) ->
                        if dns_name_length name <= remaining then
                          Some (name, tail)
                        else
                          None
                    | None -> None
                    end
                end
          | [] -> None
          end
        else
          let len = FStar.UInt8.v b in
          if len < 1 || len > 63 then
            None
          else if L.length rest < len then
            None
          else if len + 1 >= remaining then
            None
          else
            let (l, next_input) = take_label len rest in
            match parse_qname_compressed_bounded
                    (fuel - 1)
                    (remaining - (len + 1))
                    original
                    known_offsets
                    pointer_limit
                    next_input with
            | Some (tl, final_input) -> Some (l :: tl, final_input)
            | None -> None

val parse_qname_compressed :
  fuel:nat ->
  original:list FStar.UInt8.t ->
  pointer_limit:nat ->
  input:list FStar.UInt8.t ->
  Tot (option (qname * list FStar.UInt8.t)) (decreases fuel)

let parse_qname_compressed fuel original pointer_limit input =
  match parse_qname_compressed_bounded fuel 255 original (message_name_offsets original) pointer_limit input with
  | Some (name, rest) -> Some (name, rest)
  | None -> None

(* --- Safety and Termination Proofs --- *)

let lemma_parse_qname_empty_input (fuel: nat) :
  Lemma (requires (fuel > 0))
        (ensures (parse_qname fuel [] == None))
  = ()

val lemma_parse_qname_bounded_consumption :
  fuel:nat ->
  remaining:nat ->
  input:list FStar.UInt8.t ->
  Lemma (ensures (match parse_qname_bounded fuel remaining input with
                  | Some (_, rest) -> L.length rest < L.length input
                  | None -> True))
        (decreases fuel)

let rec lemma_parse_qname_bounded_consumption fuel remaining input =
  if fuel = 0 then ()
  else match input with
  | [] -> ()
  | b :: rest ->
      if b = 0uy then ()
      else if is_pointer b then ()
      else
        let len = FStar.UInt8.v b in
        if len < 1 || len > 63 then ()
        else if L.length rest < len then ()
        else if len + 1 >= remaining then ()
        else
          let (_, next_input) = take_label len rest in
          LPP.splitAt_length len rest;
          lemma_parse_qname_bounded_consumption (fuel - 1) (remaining - (len + 1)) next_input

let lemma_parse_qname_consumption (fuel: nat) (input: list FStar.UInt8.t) :
  Lemma (ensures (match parse_qname fuel input with
                  | Some (_, rest) -> L.length rest < L.length input
                  | None -> True))
  =
  lemma_parse_qname_bounded_consumption fuel 255 input

val lemma_parser_rejecting : fuel:nat -> input:list FStar.UInt8.t -> 
  Lemma (ensures (match parse_qname fuel input with
                  | Some (name, _) -> dns_name_length name <= 255
                  | None -> True))
let lemma_parser_rejecting fuel input =
  ()

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

val parse_qname_compressed_bounded :
  fuel:nat ->
  remaining:nat ->
  original:list FStar.UInt8.t ->
  pointer_limit:nat ->
  input:list FStar.UInt8.t ->
  Tot (option (qname * list FStar.UInt8.t)) (decreases fuel)

let rec parse_qname_compressed_bounded fuel remaining original pointer_limit input =
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
              if offset >= pointer_limit then
                None
              else
                begin match suffix_at offset original with
                | None -> None
                | Some target ->
                    begin match parse_qname_compressed_bounded
                            (fuel - 1)
                            remaining
                            original
                            pointer_limit
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
  parse_qname_compressed_bounded fuel 255 original pointer_limit input

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

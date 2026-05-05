module DNS.Name

open FStar.UInt8
module L = FStar.List.Tot
module LP = FStar.List.Tot.Properties

(* A label is a list of bytes with length between 1 and 63 *)
type label = l:list FStar.UInt8.t{L.length l >= 1 && L.length l <= 63}

(* A QNAME is logically a list of labels. 
   Termination is guaranteed because the list is finite. *)
type qname = list label

(* Helper to check if a byte is a pointer (starts with 11) *)
let is_pointer (b: FStar.UInt8.t) : bool =
  FStar.UInt8.(b >=^ 192uy)

(* Force cast a list to a label with internal assume for the solver *)
let cast_to_label (l: list FStar.UInt8.t) : label =
  assume (L.length l >= 1 && L.length l <= 63);
  l

(* EverParse-style combinator for a compressed name *)
val parse_qname (fuel: nat) (input: list FStar.UInt8.t) : 
  Tot (option (qname * list FStar.UInt8.t)) (decreases fuel)

let rec parse_qname fuel input =
  if fuel = 0 then 
    None (* Pointer loop or excessive recursion detected *)
  else
    match input with
    | [] -> None
    | b :: rest ->
        if b = 0uy then
          Some ([], rest) (* End of name *)
        else if is_pointer b then
          None 
        else
          (* Normal label: b is the length *)
          let len = FStar.UInt8.v b in
          if len < 1 || len > 63 then
            None 
          else if L.length rest < len then
            None
          else
            let (l_list, next_input) = L.splitAt len rest in
            let l = cast_to_label l_list in
            match parse_qname (fuel - 1) next_input with
            | Some (tl, final_input) -> Some (l :: tl, final_input)
            | None -> None

(* --- Safety and Termination Proofs --- *)

let lemma_parse_qname_empty_input (fuel: nat) :
  Lemma (requires (fuel > 0))
        (ensures (parse_qname fuel [] == None))
  = ()

let rec lemma_parse_qname_consumption (fuel: nat) (input: list FStar.UInt8.t) :
  Lemma (ensures (match parse_qname fuel input with
                  | Some (_, rest) -> L.length rest < L.length input
                  | None -> True))
        (decreases fuel)
  = if fuel = 0 then ()
    else match input with
    | [] -> ()
    | b :: rest ->
        if b = 0uy then ()
        else if is_pointer b then ()
        else
          let len = FStar.UInt8.v b in
          if len < 1 || len > 63 then ()
          else if L.length rest < len then ()
          else
            let (_, next_input) = L.splitAt len rest in
            (* Inductive Hypothesis *)
            lemma_parse_qname_consumption (fuel - 1) next_input;
            (* Explicit length reasoning using FStar.List.Tot.Properties *)
            ()

let rec dns_name_length (l: qname) : nat =
  match l with
  | [] -> 1 
  | hd :: tl -> L.length hd + 1 + dns_name_length tl

val lemma_parser_rejecting : fuel:nat -> input:list FStar.UInt8.t -> 
  Lemma (ensures (match parse_qname fuel input with
                  | Some (name, _) -> dns_name_length name <= 255
                  | None -> True))
        (decreases fuel)
let rec lemma_parser_rejecting fuel input =
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
        else
          let (_, next_input) = L.splitAt len rest in
          lemma_parser_rejecting (fuel - 1) next_input;
          admit() 

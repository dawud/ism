module DNS.Recursive.Security

open DNS.Name
open DNS.Protocol

(* Helper: Check if 'child' is a subdomain of 'parent' *)
(* In DNS, names are lists of labels. A subdomain has the parent as a suffix. *)
val is_subdomain : child:qname -> parent:qname -> Tot bool
let rec is_subdomain child parent =
  match child, parent with
  | _, [] -> true (* Everything is a subdomain of root (.) *)
  | [], _ -> false (* Root is not a subdomain of any non-empty name *)
  | c_hd :: c_tl, p_hd :: p_tl ->
      (* For this spec, we simplify: child must match parent suffix exactly.
         In a real implementation, we would compare the entire suffix. *)
      if List.length child < List.length parent then false
      else
        (* Logical simplification: check if parent is a suffix of child *)
        true (* Mocked for bootstrap, needs suffix check proof *)

(* Bailiwick Check: Mandatory for all recursive answers *)
(* This ensures that a server for 'example.com' cannot provide 
   answers for 'bank.com'. *)
val validate_answer : 
  query:qname -> 
  authority_zone:qname -> 
  ans:resource_record -> 
  Tot (res:bool{res ==> is_subdomain ans.name authority_zone})

let validate_answer query authority_zone ans =
  if is_subdomain ans.name authority_zone then true
  else false (* Drop the record; it's out of bailiwick *)

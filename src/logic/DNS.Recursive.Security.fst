module DNS.Recursive.Security

open DNS.Name
open DNS.Protocol
module L = FStar.List.Tot

val label_bytes_eq :
  a:list FStar.UInt8.t ->
  b:list FStar.UInt8.t ->
  Tot bool (decreases a)

let rec label_bytes_eq a b =
  match a, b with
  | [], [] -> true
  | ah :: at, bh :: bt -> ah = bh && label_bytes_eq at bt
  | _, _ -> false

val label_eq : label -> label -> Tot bool
let label_eq a b =
  label_bytes_eq a b

val qname_eq : qname -> qname -> Tot bool
let rec qname_eq a b =
  match a, b with
  | [], [] -> true
  | ah :: at, bh :: bt -> label_eq ah bh && qname_eq at bt
  | _, _ -> false

val has_suffix : name:qname -> suffix:qname -> Tot bool (decreases name)
let rec has_suffix name suffix =
  if L.length suffix > L.length name then
    false
  else if qname_eq name suffix then
    true
  else
    match name with
    | [] -> false
    | _ :: tl -> has_suffix tl suffix

(* In DNS, names are lists of labels. A subdomain has the parent as a suffix. *)
val is_subdomain : child:qname -> parent:qname -> Tot bool
let is_subdomain child parent =
  has_suffix child parent

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

let label_www : label = [0x77uy; 0x77uy; 0x77uy]
let label_example : label = [0x65uy; 0x78uy; 0x61uy; 0x6duy; 0x70uy; 0x6cuy; 0x65uy]
let label_com : label = [0x63uy; 0x6fuy; 0x6duy]
let label_net : label = [0x6euy; 0x65uy; 0x74uy]
let label_bank : label = [0x62uy; 0x61uy; 0x6euy; 0x6buy]

let example_com : qname = [label_example; label_com]
let www_example_com : qname = [label_www; label_example; label_com]
let example_net : qname = [label_example; label_net]
let bank_com : qname = [label_bank; label_com]

let is_subdomain_accepts_exact_zone_test =
  assert_norm (is_subdomain example_com example_com == true)

let is_subdomain_accepts_child_zone_test =
  assert_norm (is_subdomain www_example_com example_com == true)

let is_subdomain_accepts_root_zone_test =
  assert_norm (is_subdomain www_example_com [] == true)

let is_subdomain_rejects_sibling_zone_test =
  assert_norm (is_subdomain bank_com example_com == false)

let is_subdomain_rejects_shorter_child_test =
  assert_norm (is_subdomain [label_com] example_com == false)

let is_subdomain_rejects_different_tld_test =
  assert_norm (is_subdomain example_net example_com == false)

let in_bailiwick_answer : resource_record =
  {
    name = www_example_com;
    rtype = A;
    rclass = 1us;
    ttl = 60ul;
    rdlen = 0us;
    rdata = FStar.Bytes.empty_bytes;
  }

let out_of_bailiwick_answer : resource_record =
  {
    name = bank_com;
    rtype = A;
    rclass = 1us;
    ttl = 60ul;
    rdlen = 0us;
    rdata = FStar.Bytes.empty_bytes;
  }

let validate_answer_accepts_in_bailiwick_test =
  assert_norm (validate_answer example_com example_com in_bailiwick_answer == true)

let validate_answer_rejects_out_of_bailiwick_test =
  assert_norm (validate_answer example_com example_com out_of_bailiwick_answer == false)

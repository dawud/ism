module DNS.Zone.RadixTree

open DNS.Protocol
open DNS.Name
open DNS.RCode

(* A node in the Radix Tree *)
noeq
type tree_node = {
  tn_label:    label;
  tn_records:  list resource_record;
  tn_children: list tree_node;
}

(* Helper: Find a child node with a specific label *)
val find_child : list tree_node -> label -> Tot (option tree_node)
let rec find_child children l =
  match children with
  | [] -> None
  | hd :: tl ->
      if hd.tn_label = l then Some hd
      else find_child tl l

(* Termination: We use the length of the query (list of labels) as a metric.
   F* proves that because the list of labels gets smaller, the lookup must end. *)
val lookup_exact : 
  root:tree_node -> 
  query:qname -> 
  Tot (option (list resource_record)) (decreases query)

let rec lookup_exact root query =
  match query with
  | [] -> Some root.tn_records
  | hd :: tl ->
      match find_child root.tn_children hd with
      | Some child -> lookup_exact child tl
      | None -> None

(* Handling Wildcards: If exact match fails, check for '*' label *)
val lookup_with_wildcard : 
  root:tree_node -> 
  query:qname -> 
  Tot (option (list resource_record)) (decreases query)

let rec lookup_with_wildcard root query =
  match query with
  | [] -> Some root.tn_records
  | hd :: tl ->
      match find_child root.tn_children hd with
      | Some child -> lookup_with_wildcard child tl
      | None -> 
          (* Look for a literal '*' at this level (Mocked) *)
          None

(* CNAME Chasing and Loop Prevention *)
val chase_cname : 
  root:tree_node -> 
  target:qname -> 
  hops:nat{hops < 16} -> 
  Tot dns_result (decreases hops)

let rec chase_cname root target hops =
  if hops = 0 then Error ServFail (* Prevent CNAME loops *)
  else
    match lookup_with_wildcard root target with
    | Some rrs -> Success rrs
    | None -> Error NXDomain

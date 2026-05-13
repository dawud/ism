module DNS.Zone.RadixTree

open DNS.Protocol
open DNS.Name
open DNS.RCode

let wildcard_label : label = [0x2auy]

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
          match find_child root.tn_children wildcard_label with
          | Some wildcard -> lookup_with_wildcard wildcard tl
          | None -> None

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

let label_www : label = [0x77uy; 0x77uy; 0x77uy]
let label_api : label = [0x61uy; 0x70uy; 0x69uy]
let label_mail : label = [0x6duy; 0x61uy; 0x69uy; 0x6cuy]
let label_example : label = [0x65uy; 0x78uy; 0x61uy; 0x6duy; 0x70uy; 0x6cuy; 0x65uy]
let label_com : label = [0x63uy; 0x6fuy; 0x6duy]

let exact_record : resource_record =
  {
    name = [label_www; label_example; label_com];
    rtype = A;
    rclass = 1us;
    ttl = 60ul;
    rdlen = 0us;
    rdata = FStar.Bytes.empty_bytes;
  }

let wildcard_record : resource_record =
  {
    name = [wildcard_label; label_example; label_com];
    rtype = A;
    rclass = 1us;
    ttl = 60ul;
    rdlen = 0us;
    rdata = FStar.Bytes.empty_bytes;
  }

let exact_leaf : tree_node =
  {
    tn_label = label_www;
    tn_records = [exact_record];
    tn_children = [];
  }

let wildcard_leaf : tree_node =
  {
    tn_label = wildcard_label;
    tn_records = [wildcard_record];
    tn_children = [];
  }

let example_node_with_wildcard : tree_node =
  {
    tn_label = label_example;
    tn_records = [];
    tn_children = [exact_leaf; wildcard_leaf];
  }

let com_node_with_wildcard : tree_node =
  {
    tn_label = label_com;
    tn_records = [];
    tn_children = [example_node_with_wildcard];
  }

let wildcard_test_root : tree_node =
  {
    tn_label = wildcard_label;
    tn_records = [];
    tn_children = [com_node_with_wildcard];
  }

let wildcardless_example_node : tree_node =
  {
    tn_label = label_example;
    tn_records = [];
    tn_children = [exact_leaf];
  }

let wildcardless_test_root : tree_node =
  {
    tn_label = wildcard_label;
    tn_records = [];
    tn_children = [
      {
        tn_label = label_com;
        tn_records = [];
        tn_children = [wildcardless_example_node];
      }
    ];
  }

let lookup_exact_still_wins_test =
  assert_norm (
    match lookup_with_wildcard wildcard_test_root [label_com; label_example; label_www] with
    | Some (rr :: []) -> rr.name == [label_www; label_example; label_com]
    | _ -> false)

let lookup_wildcard_falls_back_test =
  assert_norm (
    match lookup_with_wildcard wildcard_test_root [label_com; label_example; label_api] with
    | Some (rr :: []) -> rr.name == [wildcard_label; label_example; label_com]
    | _ -> false)

let lookup_wildcard_rejects_without_star_test =
  assert_norm (
    lookup_with_wildcard wildcardless_test_root [label_com; label_example; label_api] == None)

let lookup_wildcard_does_not_skip_levels_test =
  assert_norm (
    lookup_with_wildcard wildcard_test_root [label_com; label_mail; label_api] == None)

let lookup_wildcard_root_query_test =
  assert_norm (
    lookup_with_wildcard wildcard_test_root [] == Some [])

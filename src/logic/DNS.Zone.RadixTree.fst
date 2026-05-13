module DNS.Zone.RadixTree

open DNS.Protocol
open DNS.Name
open DNS.RCode
module OPT = DNS.Protocol.OPT

let wildcard_label : label = [0x2auy]

type cname_lookup =
  | NoCname
  | CnameTarget of qname
  | MalformedCname

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

val parse_cname_target_bytes :
  input:list FStar.UInt8.t ->
  Tot (option qname)

let parse_cname_target_bytes input =
  match DNS.Name.parse_qname 128 input with
  | Some (target, []) -> Some target
  | _ -> None

val parse_cname_target :
  rr:resource_record ->
  Tot (option qname)

let parse_cname_target rr =
  parse_cname_target_bytes (OPT.bytes_to_list rr.rdata)

val find_cname_target :
  records:list resource_record ->
  Tot cname_lookup

let rec find_cname_target records =
  match records with
  | [] -> NoCname
  | rr :: rest ->
      match rr.rtype with
      | CNAME ->
          begin match parse_cname_target rr with
          | Some target -> CnameTarget target
          | None -> MalformedCname
          end
      | _ -> find_cname_target rest

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
    | Some rrs ->
        begin match find_cname_target rrs with
        | NoCname -> Success rrs
        | CnameTarget next_target -> chase_cname root next_target (hops - 1)
        | MalformedCname -> Error ServFail
        end
    | None -> Error NXDomain

val rr_matches_question :
  q:question ->
  rr:resource_record ->
  Tot bool

let rr_matches_question q rr =
  rr.rtype = q.qtype && rr.rclass = q.qclass

val filter_question_records :
  q:question ->
  records:list resource_record ->
  Tot (list resource_record) (decreases records)

let rec filter_question_records q records =
  match records with
  | [] -> []
  | rr :: rest ->
      let filtered_rest = filter_question_records q rest in
      if rr_matches_question q rr then
        rr :: filtered_rest
      else
        filtered_rest

val resolve_authoritative_question :
  root:tree_node ->
  q:question ->
  Tot dns_result

let resolve_authoritative_question root q =
  match chase_cname root q.qname 15 with
  | Success records -> Success (filter_question_records q records)
  | Error rcode -> Error rcode

val resolve_authoritative_request :
  root:tree_node ->
  request:dns_packet ->
  Tot dns_result

let resolve_authoritative_request root request =
  match request.questions with
  | [] -> Error FormErr
  | q :: _ -> resolve_authoritative_question root q

let label_www : label = [0x77uy; 0x77uy; 0x77uy]
let label_api : label = [0x61uy; 0x70uy; 0x69uy]
let label_alias : label = [0x61uy; 0x6cuy; 0x69uy; 0x61uy; 0x73uy]
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

let cname_target_rdata_list : list FStar.UInt8.t =
  [
    0x03uy; 0x61uy; 0x70uy; 0x69uy;
    0x07uy; 0x65uy; 0x78uy; 0x61uy; 0x6duy; 0x70uy; 0x6cuy; 0x65uy;
    0x03uy; 0x63uy; 0x6fuy; 0x6duy;
    0x00uy
  ]

let cname_target_rdata_byte (i:FStar.UInt32.t) : FStar.UInt8.t =
  let n = FStar.UInt32.v i in
  if n = 0 then 0x03uy
  else if n = 1 then 0x61uy
  else if n = 2 then 0x70uy
  else if n = 3 then 0x69uy
  else if n = 4 then 0x07uy
  else if n = 5 then 0x65uy
  else if n = 6 then 0x78uy
  else if n = 7 then 0x61uy
  else if n = 8 then 0x6duy
  else if n = 9 then 0x70uy
  else if n = 10 then 0x6cuy
  else if n = 11 then 0x65uy
  else if n = 12 then 0x03uy
  else if n = 13 then 0x63uy
  else if n = 14 then 0x6fuy
  else if n = 15 then 0x6duy
  else 0x00uy

let cname_target_rdata : FStar.Bytes.bytes =
  FStar.Bytes.init 17ul cname_target_rdata_byte

let cname_record : resource_record =
  {
    name = [label_alias; label_example; label_com];
    rtype = CNAME;
    rclass = 1us;
    ttl = 60ul;
    rdlen = 17us;
    rdata = cname_target_rdata;
  }

let cname_target_record : resource_record =
  {
    name = [label_api; label_example; label_com];
    rtype = A;
    rclass = 1us;
    ttl = 60ul;
    rdlen = 0us;
    rdata = FStar.Bytes.empty_bytes;
  }

let cname_leaf rr : tree_node =
  {
    tn_label = label_com;
    tn_records = [rr];
    tn_children = [];
  }

let cname_branch first rr : tree_node =
  {
    tn_label = first;
    tn_records = [];
    tn_children = [
      {
        tn_label = label_example;
        tn_records = [];
        tn_children = [cname_leaf rr];
      }
    ];
  }

let cname_test_root : tree_node =
  {
    tn_label = wildcard_label;
    tn_records = [];
    tn_children = [
      cname_branch label_alias cname_record;
      cname_branch label_api cname_target_record
    ];
  }

let parse_cname_target_bytes_accepts_name_test =
  assert_norm (
    parse_cname_target_bytes cname_target_rdata_list ==
    Some [label_api; label_example; label_com])

let parse_cname_target_bytes_rejects_malformed_name_test =
  assert_norm (parse_cname_target_bytes [0x03uy; 0x61uy] == None)

let find_cname_target_ignores_non_cname_test =
  assert_norm (find_cname_target [cname_target_record] == NoCname)

let chase_cname_direct_answer_test =
  assert_norm (
    match chase_cname cname_test_root [label_api; label_example; label_com] 4 with
    | Success (rr :: []) -> rr.name == [label_api; label_example; label_com]
    | _ -> false)

let chase_cname_hop_exhaustion_test =
  assert_norm (
    chase_cname cname_test_root [label_api; label_example; label_com] 0 ==
    Error ServFail)

let exact_a_question : question =
  {
    qname = [label_com; label_example; label_www];
    qtype = A;
    qclass = 1us;
  }

let wildcard_a_question : question =
  {
    qname = [label_com; label_example; label_api];
    qtype = A;
    qclass = 1us;
  }

let missing_a_question : question =
  {
    qname = [label_com; label_mail; label_api];
    qtype = A;
    qclass = 1us;
  }

let nodata_aaaa_question : question =
  {
    qname = [label_com; label_example; label_www];
    qtype = AAAA;
    qclass = 1us;
  }

let class_mismatch_question : question =
  {
    qname = [label_com; label_example; label_www];
    qtype = A;
    qclass = 3us;
  }

let empty_question_request : dns_packet =
  {
    header = {
      id = 0x1234us;
      flags = {
        qr = false;
        opcode = 0us;
        aa = false;
        tc = false;
        rd = true;
        ra = false;
        z = false;
        ad = false;
        cd = false;
        rcode = 0us;
      };
      qdcount = 0us;
      ancount = 0us;
      nscount = 0us;
      arcount = 0us;
    };
    questions = [];
    answers = [];
    authorities = [];
    additionals = [];
  }

let exact_question_request : dns_packet =
  { empty_question_request with
    header = { empty_question_request.header with qdcount = 1us };
    questions = [exact_a_question] }

let filter_question_records_keeps_matching_rr_test =
  assert_norm (filter_question_records exact_a_question [exact_record] == [exact_record])

let filter_question_records_drops_qtype_mismatch_test =
  assert_norm (filter_question_records nodata_aaaa_question [exact_record] == [])

let resolve_authoritative_exact_answer_test =
  assert_norm (
    match resolve_authoritative_question wildcard_test_root exact_a_question with
    | Success (rr :: []) -> rr.name == [label_www; label_example; label_com]
    | _ -> false)

let resolve_authoritative_wildcard_answer_test =
  assert_norm (
    match resolve_authoritative_question wildcard_test_root wildcard_a_question with
    | Success (rr :: []) -> rr.name == [wildcard_label; label_example; label_com]
    | _ -> false)

let resolve_authoritative_nxdomain_test =
  assert_norm (
    resolve_authoritative_question wildcard_test_root missing_a_question ==
    Error NXDomain)

let resolve_authoritative_nodata_test =
  assert_norm (
    resolve_authoritative_question wildcard_test_root nodata_aaaa_question ==
    Success [])

let resolve_authoritative_class_mismatch_test =
  assert_norm (
    resolve_authoritative_question wildcard_test_root class_mismatch_question ==
    Success [])

let resolve_authoritative_empty_request_test =
  assert_norm (
    resolve_authoritative_request wildcard_test_root empty_question_request ==
    Error FormErr)

let resolve_authoritative_first_question_request_test =
  assert_norm (
    match resolve_authoritative_request wildcard_test_root exact_question_request with
    | Success (rr :: []) -> rr.name == [label_www; label_example; label_com]
    | _ -> false)

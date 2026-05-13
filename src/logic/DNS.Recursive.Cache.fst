module DNS.Recursive.Cache

open FStar.HyperStack.ST
open Steel.Memory
open Steel.ST.Util
open LowStar.Buffer
open DNS.Name
open DNS.Protocol

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

(* A Cache Entry with verified TTL and metadata *)
noeq
type cache_entry = {
  ce_data:     resource_record;
  ce_inserted: FStar.UInt64.t;
  ce_expiry:   FStar.UInt64.t;
}

(* A Sharded Cache (Simplified representation for bootstrap) *)
noeq
type dns_cache = {
  c_entries: buffer (option cache_entry);
  c_size:    FStar.UInt32.t;
}

(* Helper: Check if an entry is still valid at current_time *)
val is_valid : entry:cache_entry -> current_time:FStar.UInt64.t -> Tot bool
let is_valid entry current_time =
  FStar.UInt64.v current_time < FStar.UInt64.v entry.ce_expiry

val cache_entry_matches :
  entry:cache_entry ->
  name:qname ->
  current_time:FStar.UInt64.t ->
  Tot bool

let cache_entry_matches entry name current_time =
  is_valid entry current_time && qname_eq entry.ce_data.name name

(* Verified Cache Lookup *)
val get_from_cache : 
  cache:dns_cache -> 
  name:qname -> 
  current_time:FStar.UInt64.t -> 
  ST (option resource_record)
    (requires (fun h0 ->
      live h0 cache.c_entries /\
      FStar.UInt32.v cache.c_size <= LowStar.Buffer.length cache.c_entries))
    (ensures (fun h0 res h1 -> True))

let get_from_cache cache name current_time =
  if FStar.UInt32.v cache.c_size = 0 then
    None
  else
    begin
      match LowStar.Buffer.index cache.c_entries 0ul with
      | Some entry ->
          if cache_entry_matches entry name current_time then
            Some entry.ce_data
          else
            None
      | None -> None
    end

(* Verified Cache Insertion *)
val add_to_cache : 
  cache:dns_cache -> 
  record:resource_record -> 
  current_time:FStar.UInt64.t -> 
  ST unit
    (requires (fun h0 ->
      live h0 cache.c_entries /\
      FStar.UInt32.v cache.c_size <= LowStar.Buffer.length cache.c_entries))
    (ensures (fun h0 _ h1 -> True))

let add_to_cache cache record current_time =
  (* Secure TTL Addition: We use a saturated check to prevent overflow *)
  let ttl_64 = FStar.UInt64.uint_to_t (FStar.UInt32.v record.ttl) in
  let expiry = 
    if FStar.UInt64.v current_time + FStar.UInt64.v ttl_64 > 18446744073709551615 then
      FStar.UInt64.uint_to_t 18446744073709551615
    else
      FStar.UInt64.uint_to_t (FStar.UInt64.v current_time + FStar.UInt64.v ttl_64)
  in
  let entry = {
    ce_data = record;
    ce_inserted = current_time;
    ce_expiry = expiry;
  } in
  if FStar.UInt32.v cache.c_size = 0 then
    ()
  else
    begin
      LowStar.Buffer.upd cache.c_entries 0ul (Some entry)
    end

let label_www : label = [0x77uy; 0x77uy; 0x77uy]
let label_example : label = [0x65uy; 0x78uy; 0x61uy; 0x6duy; 0x70uy; 0x6cuy; 0x65uy]
let label_com : label = [0x63uy; 0x6fuy; 0x6duy]
let label_net : label = [0x6euy; 0x65uy; 0x74uy]

let cached_record : resource_record =
  {
    name = [label_www; label_example; label_com];
    rtype = A;
    rclass = 1us;
    ttl = 60ul;
    rdlen = 0us;
    rdata = FStar.Bytes.empty_bytes;
  }

let cached_entry : cache_entry =
  {
    ce_data = cached_record;
    ce_inserted = 10UL;
    ce_expiry = 70UL;
  }

let qname_eq_accepts_equal_name_test =
  assert_norm (qname_eq [label_www; label_example; label_com]
                        [label_www; label_example; label_com] == true)

let qname_eq_rejects_different_name_test =
  assert_norm (qname_eq [label_www; label_example; label_com]
                        [label_www; label_example; label_net] == false)

let cache_entry_matches_valid_name_test =
  assert_norm (cache_entry_matches cached_entry [label_www; label_example; label_com] 20UL == true)

let cache_entry_rejects_expired_name_test =
  assert_norm (cache_entry_matches cached_entry [label_www; label_example; label_com] 70UL == false)

let cache_entry_rejects_different_name_test =
  assert_norm (cache_entry_matches cached_entry [label_www; label_example; label_net] 20UL == false)

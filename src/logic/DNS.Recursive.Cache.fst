module DNS.Recursive.Cache

open FStar.HyperStack.ST
open Steel.Memory
open Steel.ST.Util
open LowStar.Buffer
open LowStar.Modifies
open DNS.Name
open DNS.Protocol

val label_bytes_eq :
  a:list FStar.UInt8.t ->
  b:list FStar.UInt8.t ->
  Tot bool (decreases a)

let label_bytes_eq a b =
  DNS.Name.canonical_bytes a = DNS.Name.canonical_bytes b

val label_eq : label -> label -> Tot bool
let label_eq a b = DNS.Name.label_eq a b

val qname_eq : qname -> qname -> Tot bool
let qname_eq a b = DNS.Name.qname_eq a b

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

let cached_value (entry:cache_entry) (name:qname) (now:FStar.UInt64.t)
  : Tot (option resource_record) =
  if not (cache_entry_matches entry name now) then None else
  let remaining = FStar.UInt64.v entry.ce_expiry - FStar.UInt64.v now in
  let ttl = if remaining < FStar.UInt32.v entry.ce_data.ttl
            then FStar.UInt32.uint_to_t remaining else entry.ce_data.ttl in
  Some { entry.ce_data with ttl = ttl }

let lemma_cached_value_is_fresh (entry:cache_entry) (name:qname) (now:FStar.UInt64.t)
  : Lemma (match cached_value entry name now with
    | None -> True
    | Some rr -> DNS.Name.qname_eq rr.name name /\
        FStar.UInt64.v now < FStar.UInt64.v entry.ce_expiry /\
        FStar.UInt32.v rr.ttl <= FStar.UInt32.v entry.ce_data.ttl /\
        FStar.UInt32.v rr.ttl <= FStar.UInt64.v entry.ce_expiry - FStar.UInt64.v now) = ()

let lookup_slot (slot:option cache_entry) (name:qname) (now:FStar.UInt64.t)
  : Tot (option resource_record) =
  match slot with | None -> None | Some entry -> cached_value entry name now

let new_entry (record:resource_record) (now:FStar.UInt64.t) : cache_entry =
  let expiry = if FStar.UInt64.v now + FStar.UInt32.v record.ttl > 18446744073709551615
    then 18446744073709551615 else FStar.UInt64.v now + FStar.UInt32.v record.ttl in
  { ce_data = record; ce_inserted = now; ce_expiry = FStar.UInt64.uint_to_t expiry }

(* Verified Cache Lookup *)
val get_from_cache : 
  cache:dns_cache -> 
  name:qname -> 
  current_time:FStar.UInt64.t -> 
  ST (option resource_record)
    (requires (fun h0 ->
      live h0 cache.c_entries /\
      FStar.UInt32.v cache.c_size <= LowStar.Buffer.length cache.c_entries))
    (ensures (fun h0 res h1 -> modifies_none h0 h1 /\
      res == (if FStar.UInt32.v cache.c_size = 0 then None else
        lookup_slot (FStar.Seq.index (as_seq h0 cache.c_entries) 0) name current_time)))

let get_from_cache cache name current_time =
  if FStar.UInt32.v cache.c_size = 0 then
    None
  else
    begin
      match LowStar.Buffer.index cache.c_entries 0ul with
      | Some entry ->
          cached_value entry name current_time
      | None -> None
    end

(* Sequential, policy-checked insertion. This suffix check is not a complete
   recursive resolver's referral/ranking/DNSSEC validation policy. *)
val add_to_cache : 
  cache:dns_cache -> 
  query:qname -> authority_zone:qname ->
  record:resource_record -> 
  current_time:FStar.UInt64.t -> 
  ST bool
    (requires (fun h0 ->
      live h0 cache.c_entries /\
      FStar.UInt32.v cache.c_size <= LowStar.Buffer.length cache.c_entries))
    (ensures (fun h0 inserted h1 ->
      modifies (loc_buffer cache.c_entries) h0 h1 /\ live h1 cache.c_entries /\
      (if inserted then
        DNS.Recursive.Security.is_subdomain record.name authority_zone /\
        FStar.UInt32.v cache.c_size > 0 /\
        as_seq h1 cache.c_entries == FStar.Seq.upd (as_seq h0 cache.c_entries) 0
          (Some (new_entry record current_time))
       else modifies_none h0 h1)))

let add_to_cache cache query authority_zone record current_time =
  if FStar.UInt32.v cache.c_size = 0 ||
     not (DNS.Recursive.Security.validate_answer query authority_zone record) ||
     not (DNS.Protocol.Serializer.well_formed_record record) then
    false
  else
    begin
      LowStar.Buffer.upd cache.c_entries 0ul (Some (new_entry record current_time));
      true
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

module DNS.Cache.Sharded

open FStar.HyperStack.ST
open LowStar.Buffer
open Steel.Memory
open Steel.ST.Util
open DNS.Name
open DNS.Protocol
open DNS.Recursive.Cache

(* A shard is a shareable reference to a cache portion *)
type shard = dns_cache

(* A Steel 'view' property placeholder. The current bootstrap Steel adapter
   erases vprop to unit; real shard invariants are tracked as trusted debt. *)
val shard_permission : s:shard -> Tot vprop
let shard_permission s = ()

(* The Global Sharded Cache *)
noeq
type sharded_cache = {
  sc_shards: buffer shard;
  sc_num:    FStar.UInt32.t;
}

(* Helper: Get a shard index from a QNAME hash. Bootstrap routing always uses
   the first shard; real hashing remains future work. *)
val get_shard_index :
  name:qname ->
  num_shards:FStar.UInt32.t{FStar.UInt32.v num_shards > 0} ->
  Tot (n:FStar.UInt32.t{FStar.UInt32.v n < FStar.UInt32.v num_shards})
let get_shard_index name num_shards =
  0ul

(* Concurrent Cache Get *)
val concurrent_get : 
  sc:sharded_cache -> 
  name:qname -> 
  now:FStar.UInt64.t -> 
  ST (option resource_record)
    (requires (fun h0 ->
      live h0 sc.sc_shards /\
      FStar.UInt32.v sc.sc_num <= LowStar.Buffer.length sc.sc_shards /\
      (FStar.UInt32.v sc.sc_num > 0 ==>
       (let shard = FStar.Seq.index (LowStar.Buffer.as_seq h0 sc.sc_shards) 0 in
        live h0 shard.c_entries /\
        FStar.UInt32.v shard.c_size <= LowStar.Buffer.length shard.c_entries))))
    (ensures (fun h0 _ h1 -> True))

let concurrent_get sc name now =
  if FStar.UInt32.v sc.sc_num = 0 then
    None
  else
    let idx = get_shard_index name sc.sc_num in
    let shard = LowStar.Buffer.index sc.sc_shards idx in
    get_from_cache shard name now

(* Concurrent Cache Add *)
val concurrent_add : 
  sc:sharded_cache -> 
  record:resource_record -> 
  now:FStar.UInt64.t -> 
  ST unit
    (requires (fun h0 ->
      live h0 sc.sc_shards /\
      FStar.UInt32.v sc.sc_num <= LowStar.Buffer.length sc.sc_shards /\
      (FStar.UInt32.v sc.sc_num > 0 ==>
       (let shard = FStar.Seq.index (LowStar.Buffer.as_seq h0 sc.sc_shards) 0 in
        live h0 shard.c_entries /\
        FStar.UInt32.v shard.c_size <= LowStar.Buffer.length shard.c_entries))))
    (ensures (fun h0 _ h1 -> True))

let concurrent_add sc record now =
  if FStar.UInt32.v sc.sc_num = 0 then
    ()
  else
    let idx = get_shard_index record.name sc.sc_num in
    let shard = LowStar.Buffer.index sc.sc_shards idx in
    add_to_cache shard record now

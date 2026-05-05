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

(* A Steel 'view' property: proves a thread has the right to access this shard *)
assume
val shard_permission (s: shard) : vprop

(* The Global Sharded Cache *)
noeq
type sharded_cache = {
  sc_shards: buffer shard;
  sc_num:    FStar.UInt32.t;
}

(* Helper: Get a shard index from a QNAME hash *)
val get_shard_index : name:qname -> num_shards:FStar.UInt32.t -> Tot (n:FStar.UInt32.t{FStar.UInt32.v n < FStar.UInt32.v num_shards})
let get_shard_index name num_shards =
  if FStar.UInt32.v num_shards > 0 then
    0ul
  else
    admit()

(* Concurrent Cache Get *)
val concurrent_get : 
  sc:sharded_cache -> 
  name:qname -> 
  now:FStar.UInt64.t -> 
  ST (option resource_record)
    (requires (fun h0 -> True))
    (ensures (fun h0 _ h1 -> True))

let concurrent_get sc name now =
  admit()

(* Concurrent Cache Add *)
val concurrent_add : 
  sc:sharded_cache -> 
  record:resource_record -> 
  now:FStar.UInt64.t -> 
  ST unit
    (requires (fun h0 -> True))
    (ensures (fun h0 _ h1 -> True))

let concurrent_add sc record now =
  admit()

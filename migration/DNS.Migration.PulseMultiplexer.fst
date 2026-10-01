module DNS.Migration.PulseMultiplexer
#lang-pulse

open Pulse.Lib.Pervasives
open Pulse.Lib.Array
module A = Pulse.Lib.Array
module R = Pulse.Lib.Reference
module S = FStar.Seq
module SP = FStar.Seq.Properties
module G = FStar.Ghost
module SZ = FStar.SizeT
module U32 = FStar.UInt32
module U64 = FStar.UInt64
module P = DNS.Migration.PulseStream
module M = DNS.QUIC.StreamModel
module T = DNS.QUIC.TableModel

type slot = R.ref P.stream_context
type snapshot = slot -> GTot P.stream_context
noeq
type connection_context = {
  cc_active: A.array slot;
  cc_num: U32.t;
  cc_capacity: U32.t;
}

(* Separate ownership of each context, independent of its position in the
   pointer permutation. Message resources are framed: these operations neither
   dereference, allocate nor free message storage. *)
let rec contexts_from (pool:S.seq slot) (state:snapshot)
  (start skip:nat) : Tot slprop (decreases (S.length pool - start)) =
  if start >= S.length pool then emp else
  if start = skip then contexts_from pool state (start + 1) skip else
  R.pts_to (S.index pool start) (state (S.index pool start)) ** contexts_from pool state (start + 1) skip

let contexts (pool:S.seq slot) (state:snapshot) : slprop =
  contexts_from pool state 0 (S.length pool)

(* A finite ghost search supplies the witness; no choice/ownership axiom. *)
let rec pool_index (pool:S.seq slot) (p:slot)
  (start:nat{exists (j:nat). start <= j /\ j < S.length pool /\ S.index pool j == p})
  : GTot (j:nat{start <= j /\ j < S.length pool /\ S.index pool j == p})
    (decreases (S.length pool - start)) =
  if Prims.t2b (S.index pool start == p) then start else pool_index pool p (start + 1)

let rec lemma_contexts_eq (pool:S.seq slot) (before after:snapshot)
  (start skip0 skip1:nat)
  : Lemma
    (requires (forall (j:nat). start <= j /\ j < S.length pool ==>
      ((j = skip0 <==> j = skip1) /\
       (j <> skip0 ==> before (S.index pool j) == after (S.index pool j)))))
    (ensures (contexts_from pool before start skip0 == contexts_from pool after start skip1))
    (decreases (S.length pool - start)) =
  if start < S.length pool then (
    lemma_contexts_eq pool before after (start + 1) skip0 skip1;
    if start = skip0 then () else ())

ghost
fn rec take_context (pool:S.seq slot) (state:snapshot) (start:nat)
  (index:nat{start <= index /\ index < S.length pool})
requires contexts_from pool state start (S.length pool)
requires pure (start <= index /\ index < S.length pool)
ensures R.pts_to (S.index pool index) (state (S.index pool index)) **
  contexts_from pool state start index
decreases (index - start)
{
  rewrite contexts_from pool state start (S.length pool) as
    (R.pts_to (S.index pool start) (state (S.index pool start)) **
     contexts_from pool state (start + 1) (S.length pool));
  if (start < index) {
    take_context pool state (start + 1) index;
    rewrite (R.pts_to (S.index pool start) (state (S.index pool start)) ** contexts_from pool state (start + 1) index)
      as contexts_from pool state start index;
  } else {
    rewrite R.pts_to (S.index pool start) (state (S.index pool start)) as
      R.pts_to (S.index pool index) (state (S.index pool index));
    lemma_contexts_eq pool state state (start + 1) (S.length pool) index;
    rewrite contexts_from pool state (start + 1) (S.length pool) as contexts_from pool state (start + 1) index;
    rewrite contexts_from pool state (start + 1) index as contexts_from pool state start index;
  };
}

ghost
fn rec put_context (pool:S.seq slot) (before after:snapshot) (start:nat)
  (index:nat{start <= index /\ index < S.length pool})
requires contexts_from pool before start index ** R.pts_to (S.index pool index) (after (S.index pool index))
requires pure (start <= index /\ index < S.length pool /\
  (forall (j:nat). start <= j /\ j < S.length pool /\ j <> index ==>
    before (S.index pool j) == after (S.index pool j)))
ensures contexts_from pool after start (S.length pool)
decreases (S.length pool - start)
{
  if (start < index) {
    rewrite contexts_from pool before start index as
      (R.pts_to (S.index pool start) (before (S.index pool start)) **
       contexts_from pool before (start + 1) index);
    put_context pool before after (start + 1) index;
    rewrite R.pts_to (S.index pool start) (before (S.index pool start)) as
      R.pts_to (S.index pool start) (after (S.index pool start));
    rewrite (R.pts_to (S.index pool start) (after (S.index pool start)) **
      contexts_from pool after (start + 1) (S.length pool)) as contexts_from pool after start (S.length pool);
  } else {
    rewrite contexts_from pool before start index as contexts_from pool before (start + 1) index;
    lemma_contexts_eq pool before after (start + 1) index (S.length pool);
    rewrite contexts_from pool before (start + 1) index as contexts_from pool after (start + 1) (S.length pool);
    rewrite (R.pts_to (S.index pool index) (after (S.index pool index)) **
      contexts_from pool after (start + 1) (S.length pool)) as contexts_from pool after start (S.length pool);
  };
}

fn read_slot (table:A.array slot) (i:U32.t)
  (#slots #pool:G.erased (S.seq slot)) (#state:G.erased snapshot)
requires A.pts_to table slots ** contexts pool state
requires pure (U32.v i < S.length slots /\
  (forall p. T.contains slots p ==> T.contains pool p))
returns value:P.stream_context
ensures A.pts_to table slots ** contexts pool state **
  pure (U32.v i < S.length slots /\ value == (G.reveal state) (S.index slots (U32.v i)))
{
  A.pts_to_len table;
  let p = table.(SZ.uint32_to_sizet i);
  assert (pure (T.contains pool p));
  let index = G.hide (pool_index pool p 0);
  unfold contexts;
  take_context pool state 0 index;
  rewrite R.pts_to (S.index pool index) ((G.reveal state) (S.index pool index)) as
    R.pts_to p ((G.reveal state) p);
  let value = R.read p #(G.hide ((G.reveal state) p));
  rewrite R.pts_to p value as R.pts_to (S.index pool index) ((G.reveal state) (S.index pool index));
  put_context pool state state 0 index;
  fold contexts;
  value
}

(* Return count on a miss; otherwise the first matching active index. *)
fn find_index (table:A.array slot) (count:U32.t) (id:U64.t)
  (#slots #pool:G.erased (S.seq slot)) (#state:G.erased snapshot)
requires A.pts_to table slots ** contexts pool state
requires pure (U32.v count <= S.length slots /\
  (forall p. T.contains slots p ==> T.contains pool p))
returns result:U32.t
ensures A.pts_to table slots ** contexts pool state ** pure (
  U32.v count <= S.length slots /\ U32.v result <= U32.v count /\
  (forall (j:nat). j < U32.v result ==> ((G.reveal state) (S.index slots j)).P.sc_id <> id) /\
  (U32.v result < U32.v count ==> ((G.reveal state) (S.index slots (U32.v result))).P.sc_id == id))
{
  let mut i = 0ul;
  let mut found = false;
  while (U32.lt !i count && not !found)
  invariant exists* (idx:U32.t) (hit:bool).
    R.pts_to i idx ** R.pts_to found hit **
    A.pts_to table slots ** contexts pool state ** pure (
      U32.v count <= S.length slots /\ U32.v idx <= U32.v count /\
      (forall (j:nat). j < U32.v idx ==> ((G.reveal state) (S.index slots j)).P.sc_id <> id) /\
      (hit ==> U32.v idx < U32.v count /\
        ((G.reveal state) (S.index slots (U32.v idx))).P.sc_id == id))
  decreases (if !found then 0 else U32.v count - U32.v !i + 1)
  {
    let idx = !i;
    let value = read_slot table idx;
    if (U64.eq value.P.sc_id id) {
      found := true;
    } else {
      i := U32.add idx 1ul;
    };
  };
  !i
}

let updated (state:snapshot) (p:slot) (value:P.stream_context)
  : GTot snapshot =
  fun q -> if Prims.t2b (q == p) then value else state q

fn replace_context (p:slot) (value:P.stream_context)
  (#pool:G.erased (S.seq slot)) (#state:G.erased snapshot)
requires contexts pool state
requires pure (T.contains pool p /\ T.distinct pool)
ensures contexts pool (updated state p value)
{
  let index = G.hide (pool_index pool p 0);
  unfold contexts;
  take_context pool state 0 index;
  rewrite R.pts_to (S.index pool index) ((G.reveal state) (S.index pool index)) as
    R.pts_to p ((G.reveal state) p);
  p := value;
  let next = G.hide (updated state p value);
  rewrite R.pts_to p value as R.pts_to (S.index pool index) ((G.reveal next) (S.index pool index));
  put_context pool state next 0 index;
  fold contexts;
  rewrite contexts pool next as contexts pool (updated state p value);
}

let table_ok (conn:connection_context) (slots pool:S.seq slot) : prop =
  U32.v conn.cc_num <= U32.v conn.cc_capacity /\
  U32.v conn.cc_capacity <= S.length slots /\ S.length slots < 4294967296 /\
  T.distinct slots /\ T.distinct pool /\
  (forall p. T.contains slots p ==> T.contains pool p)

fn find_stream (conn_ptr:R.ref connection_context) (id:U64.t)
  (#conn:G.erased connection_context) (#slots #pool:G.erased (S.seq slot))
  (#state:G.erased snapshot)
requires R.pts_to conn_ptr conn ** A.pts_to conn.cc_active slots ** contexts pool state
requires pure (table_ok conn slots pool)
returns result:U32.t
ensures R.pts_to conn_ptr conn ** A.pts_to conn.cc_active slots ** contexts pool state ** pure (
  U32.v conn.cc_num <= S.length slots /\ U32.v result <= U32.v conn.cc_num /\
  (forall (j:nat). j < U32.v result ==> ((G.reveal state) (S.index slots j)).P.sc_id <> id) /\
  (U32.v result < U32.v conn.cc_num ==> ((G.reveal state) (S.index slots (U32.v result))).P.sc_id == id))
{
  let c = !conn_ptr;
  find_index c.cc_active c.cc_num id
}

(* Capacity is the failure sentinel. On success only the first available
   context's ID/phase and the connection count change; no allocation occurs. *)
fn allocate_stream (conn_ptr:R.ref connection_context) (id:U64.t)
  (#conn:G.erased connection_context) (#slots #pool:G.erased (S.seq slot))
  (#state:G.erased snapshot)
requires R.pts_to conn_ptr conn ** A.pts_to conn.cc_active slots ** contexts pool state
requires pure (table_ok conn slots pool)
returns result:U32.t
ensures exists* (count:U32.t) (next:snapshot).
  R.pts_to conn_ptr ({conn with cc_num = count}) ** A.pts_to conn.cc_active slots ** contexts pool next ** pure (
    let after = {conn with cc_num = count} in
    table_ok conn slots pool /\ table_ok after slots pool /\ after.cc_active == conn.cc_active /\ after.cc_capacity == conn.cc_capacity /\
    (result == conn.cc_capacity <==> conn.cc_num == conn.cc_capacity \/
      (exists (j:nat). j < U32.v conn.cc_num /\ ((G.reveal state) (S.index slots j)).P.sc_id == id)) /\
    (if result == conn.cc_capacity then after == conn /\ next == G.reveal state else
      result == conn.cc_num /\ U32.v result < U32.v conn.cc_capacity /\
      after == {conn with cc_num = U32.add conn.cc_num 1ul} /\
      (let p = S.index slots (U32.v result) in
       next == updated state p { (G.reveal state) p with P.sc_id = id; P.sc_phase = M.ReadingLength })) /\
    (forall (j:nat). j < U32.v conn.cc_num ==> next (S.index slots j) == (G.reveal state) (S.index slots j)))
{
  let c = !conn_ptr;
  let existing = find_index c.cc_active c.cc_num id;
  if (U32.lt existing c.cc_num || not (U32.lt c.cc_num c.cc_capacity)) {
    rewrite R.pts_to conn_ptr c as R.pts_to conn_ptr ({conn with cc_num = c.cc_num});
    c.cc_capacity
  } else {
    A.pts_to_len c.cc_active;
    let p = c.cc_active.(SZ.uint32_to_sizet c.cc_num);
    let old = read_slot c.cc_active c.cc_num;
    let fresh = {old with P.sc_id = id; P.sc_phase = M.ReadingLength};
    replace_context p fresh;
    conn_ptr := {c with cc_num = U32.add c.cc_num 1ul};
    c.cc_num
  }
}

fn close_stream (conn_ptr:R.ref connection_context) (id:U64.t)
  (#conn:G.erased connection_context) (#slots #pool:G.erased (S.seq slot))
  (#state:G.erased snapshot)
requires R.pts_to conn_ptr conn ** A.pts_to conn.cc_active slots ** contexts pool state
requires pure (table_ok conn slots pool)
returns closed:bool
ensures exists* (count:U32.t) (order:S.seq slot).
  R.pts_to conn_ptr ({conn with cc_num = count}) ** A.pts_to conn.cc_active order ** contexts pool state ** pure (
    let after = {conn with cc_num = count} in
    table_ok conn slots pool /\ table_ok after order pool /\ after.cc_active == conn.cc_active /\ after.cc_capacity == conn.cc_capacity /\
    (if closed then
      U32.v conn.cc_num > 0 /\ U32.v conn.cc_num <= S.length slots /\
      after == {conn with cc_num = U32.sub conn.cc_num 1ul} /\
      (exists (removed:nat). removed < U32.v conn.cc_num /\
        ((G.reveal state) (S.index slots removed)).P.sc_id == id /\
        (forall (j:nat). j < removed ==> ((G.reveal state) (S.index slots j)).P.sc_id <> id) /\
        order == SP.swap slots removed (U32.v conn.cc_num - 1))
     else after == conn /\ order == slots /\
       (forall (j:nat). j < U32.v conn.cc_num ==> ((G.reveal state) (S.index slots j)).P.sc_id <> id)))
{
  let c = !conn_ptr;
  let found = find_index c.cc_active c.cc_num id;
  if (U32.lt found c.cc_num) {
    A.pts_to_len c.cc_active;
    let last = U32.sub c.cc_num 1ul;
    let removed = c.cc_active.(SZ.uint32_to_sizet found);
    let final = c.cc_active.(SZ.uint32_to_sizet last);
    c.cc_active.(SZ.uint32_to_sizet last) <- removed;
    c.cc_active.(SZ.uint32_to_sizet found) <- final;
    T.lemma_swap_distinct slots (U32.v found) (U32.v last);
    T.lemma_swap_contains slots (U32.v found) (U32.v last);
    conn_ptr := {c with cc_num = last};
    true
  } else {
    rewrite R.pts_to conn_ptr c as R.pts_to conn_ptr ({conn with cc_num = c.cc_num});
    false
  }
}

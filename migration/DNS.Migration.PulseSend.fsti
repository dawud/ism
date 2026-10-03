module DNS.Migration.PulseSend
#lang-pulse

open Pulse.Lib.Pervasives
module A = Pulse.Lib.Array
module R = Pulse.Lib.Reference
module S = FStar.Seq
module SP = FStar.Seq.Properties
module G = FStar.Ghost
module U8 = FStar.UInt8
module U32 = FStar.UInt32
module U64 = FStar.UInt64
module M = DNS.Migration.PulseMultiplexer
module P = DNS.Migration.PulseStream

noeq
type descriptor = {
  stream_id: U64.t;
  data: A.array U8.t;
  length: U32.t;
  fin: bool;
  context: M.slot;
}

noeq
type reservation = { send:descriptor; index:U32.t }
type send_slot = R.ref (option reservation)
type outcome = | SendCompleted | SendDropped

[@@pulse_unfold]
let connection_owned (cp:R.ref M.connection_context) (c:M.connection_context)
  (slots pool:S.seq M.slot) (state:M.snapshot) : slprop =
  R.pts_to cp c ** A.pts_to c.M.cc_active slots ** M.contexts pool state

[@@pulse_unfold]
let idle_resources (slot:send_slot) (cp:R.ref M.connection_context)
  (response:A.array U8.t) (bytes:S.seq U8.t) (c:M.connection_context)
  (slots pool:S.seq M.slot) (state:M.snapshot) : slprop =
  R.pts_to slot None ** A.pts_to response bytes ** connection_owned cp c slots pool state

(* Both predicates have checked implementations, not assumed ownership axioms.
   pending owns only the response storage. The independent guarded connection
   permits serialized table operations while preserving the reserved context.
   Neither predicate exposes writable buffer/context/control resources. *)
val pending ([@@@mkey] slot:send_slot) (d:descriptor) (bytes:S.seq U8.t) : slprop

val reserved_connection ([@@@mkey] slot:send_slot) (cp:R.ref M.connection_context)
  (d:descriptor) (saved:P.stream_context) (c:M.connection_context)
  (slots pool:S.seq M.slot) (state:M.snapshot) : slprop

let lookup_result (c:M.connection_context) (slots:S.seq M.slot)
  (state:M.snapshot) (id:U64.t) (result:U32.t) : prop =
  U32.v c.M.cc_num <= S.length slots /\ U32.v result <= U32.v c.M.cc_num /\
  (forall (j:nat). j < U32.v result ==> (state (S.index slots j)).P.sc_id <> id) /\
  (U32.v result < U32.v c.M.cc_num ==> (state (S.index slots (U32.v result))).P.sc_id == id)

let allocation_result (c:M.connection_context) (slots pool:S.seq M.slot)
  (state:M.snapshot) (id:U64.t) (result count:U32.t) (next:M.snapshot) : prop =
  M.table_ok c slots pool /\ M.table_ok ({c with M.cc_num = count}) slots pool /\
  (result == c.M.cc_capacity <==> c.M.cc_num == c.M.cc_capacity \/
    (exists (j:nat). j < U32.v c.M.cc_num /\ (state (S.index slots j)).P.sc_id == id)) /\
  (if result == c.M.cc_capacity then count == c.M.cc_num /\ next == state else
    result == c.M.cc_num /\ U32.v result < U32.v c.M.cc_capacity /\
    count == U32.add c.M.cc_num 1ul /\
    (let p = S.index slots (U32.v result) in
     next == M.updated state p {state p with P.sc_id = id; P.sc_phase = DNS.QUIC.StreamModel.ReadingLength})) /\
  (forall (j:nat). j < U32.v c.M.cc_num ==> next (S.index slots j) == state (S.index slots j))

let other_close_result (d:descriptor) (c:M.connection_context)
  (slots pool:S.seq M.slot) (state:M.snapshot) (id:U64.t)
  (closed:bool) (count:U32.t) (order:S.seq M.slot) : prop =
  M.table_ok c slots pool /\ M.table_ok ({c with M.cc_num = count}) order pool /\
  (if closed then
    id <> d.stream_id /\ U32.v c.M.cc_num > 0 /\ count == U32.sub c.M.cc_num 1ul /\
    (exists (removed:nat). removed < U32.v c.M.cc_num /\
      (state (S.index slots removed)).P.sc_id == id /\
      (forall (j:nat). j < removed ==> (state (S.index slots j)).P.sc_id <> id) /\
      order == SP.swap slots removed (U32.v c.M.cc_num - 1))
   else count == c.M.cc_num /\ order == slots /\
     (id == d.stream_id \/ (forall (j:nat). j < U32.v c.M.cc_num ==>
       (state (S.index slots j)).P.sc_id <> id)))

(* Completion removes the reserved context, not whichever duplicate ID happens
   to appear first after intervening compaction. All current context values are
   preserved, including changes to other contexts made while the send waited. *)
let close_result (d:descriptor) (c:M.connection_context) (slots pool:S.seq M.slot)
  (state:M.snapshot) (count:U32.t) (order:S.seq M.slot) : prop =
  M.table_ok c slots pool /\ M.table_ok ({c with M.cc_num = count}) order pool /\
  U32.v c.M.cc_num > 0 /\ count == U32.sub c.M.cc_num 1ul /\
  (exists (removed:nat). removed < U32.v c.M.cc_num /\
    S.index slots removed == d.context /\ (state d.context).P.sc_id == d.stream_id /\
    order == SP.swap slots removed (U32.v c.M.cc_num - 1)) /\
  (forall (j:nat). j < U32.v count ==> S.index order j =!= d.context)

fn begin_send (slot:send_slot) (cp:R.ref M.connection_context)
  (response:A.array U8.t) (length:U32.t) (id:U64.t) (fin:bool)
  (#bytes:G.erased (S.seq U8.t)) (#c:G.erased M.connection_context)
  (#slots #pool:G.erased (S.seq M.slot)) (#state:G.erased M.snapshot)
requires idle_resources slot cp response bytes c slots pool state
requires pure (M.table_ok c slots pool /\ U32.v length <= S.length bytes)
returns result:option descriptor
ensures (match result with
  | None -> idle_resources slot cp response bytes c slots pool state
  | Some d -> pending slot d bytes **
      reserved_connection slot cp d ((G.reveal state) d.context) c slots pool state ** pure (
      d.stream_id == id /\ d.data == response /\ d.length == length /\ d.fin == fin /\
      (exists (j:nat). j < U32.v c.M.cc_num /\ j < S.length slots /\
        S.index slots j == d.context /\
        ((G.reveal state) d.context).P.sc_id == id /\
        (forall (k:nat). k < j ==> ((G.reveal state) (S.index slots k)).P.sc_id <> id))))
ensures pure (None? result <==>
  (forall (j:nat). j < U32.v c.M.cc_num /\ j < S.length slots ==>
    ((G.reveal state) (S.index slots j)).P.sc_id <> id))

fn inspect_pending (slot:send_slot) (cp:R.ref M.connection_context)
  (#d:G.erased descriptor) (#saved:G.erased P.stream_context)
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires reserved_connection slot cp d saved c slots pool state
returns result:descriptor
ensures reserved_connection slot cp d saved c slots pool state ** pure (result == d)

fn find_while_pending (slot:send_slot) (cp:R.ref M.connection_context) (id:U64.t)
  (#d:G.erased descriptor) (#saved:G.erased P.stream_context)
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires reserved_connection slot cp d saved c slots pool state
returns result:U32.t
ensures reserved_connection slot cp d saved c slots pool state **
  pure (lookup_result c slots state id result)

fn allocate_while_pending (slot:send_slot) (cp:R.ref M.connection_context) (id:U64.t)
  (#d:G.erased descriptor) (#saved:G.erased P.stream_context)
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires reserved_connection slot cp d saved c slots pool state
returns result:U32.t
ensures exists* (count:U32.t) (next:M.snapshot).
  reserved_connection slot cp d saved ({c with M.cc_num = count}) slots pool next **
  pure (allocation_result c slots pool state id result count next)

fn close_other (slot:send_slot) (cp:R.ref M.connection_context) (id:U64.t)
  (#d:G.erased descriptor) (#saved:G.erased P.stream_context)
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires reserved_connection slot cp d saved c slots pool state
returns closed:bool
ensures exists* (count:U32.t) (order:S.seq M.slot).
  reserved_connection slot cp d saved ({c with M.cc_num = count}) order pool state **
  pure (other_close_result d c slots pool state id closed count order)

(* Matching ID is a modeled notification, not evidence of transport quiescence.
   Truthful completion/drop after transport release remains a caller obligation.
   This API does not address same-ID replay/generation protection. *)
fn finish_send (slot:send_slot) (cp:R.ref M.connection_context)
  (completion_id:U64.t) (outcome:outcome)
  (#d:G.erased descriptor) (#bytes:G.erased (S.seq U8.t))
  (#saved:G.erased P.stream_context) (#c:G.erased M.connection_context)
  (#slots #pool:G.erased (S.seq M.slot)) (#state:G.erased M.snapshot)
requires pending slot d bytes ** reserved_connection slot cp d saved c slots pool state
returns accepted:bool
ensures pure (accepted <==> completion_id == d.stream_id)
ensures (if accepted then
  exists* (count:U32.t) (order:S.seq M.slot).
    R.pts_to slot None ** A.pts_to d.data bytes **
    connection_owned cp ({c with M.cc_num = count}) order pool state **
    pure (close_result d c slots pool state count order /\ (G.reveal state) d.context == saved)
  else pending slot d bytes ** reserved_connection slot cp d saved c slots pool state)

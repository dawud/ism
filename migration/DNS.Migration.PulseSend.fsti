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
}

type send_slot = R.ref (option descriptor)
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

(* Implemented, not assumed. The interface deliberately hides all owned
   buffer/table/slot resources while pending; no public unseal operation. *)
val pending ([@@@mkey] slot:send_slot) (cp:R.ref M.connection_context)
  (d:descriptor) (bytes:S.seq U8.t) (c:M.connection_context)
  (slots pool:S.seq M.slot) (state:M.snapshot) : slprop

let close_result (c:M.connection_context) (slots pool:S.seq M.slot) (state:M.snapshot)
  (id:U64.t) (count:U32.t) (order:S.seq M.slot) : prop =
  M.table_ok c slots pool /\ M.table_ok ({c with M.cc_num = count}) order pool /\
  U32.v c.M.cc_num > 0 /\ count == U32.sub c.M.cc_num 1ul /\
  (exists (removed:nat). removed < U32.v c.M.cc_num /\
    (state (S.index slots removed)).P.sc_id == id /\
    (forall (j:nat). j < removed ==> (state (S.index slots j)).P.sc_id <> id) /\
    order == SP.swap slots removed (U32.v c.M.cc_num - 1))

fn begin_send (slot:send_slot) (cp:R.ref M.connection_context)
  (response:A.array U8.t) (length:U32.t) (id:U64.t) (fin:bool)
  (#bytes:G.erased (S.seq U8.t)) (#c:G.erased M.connection_context)
  (#slots #pool:G.erased (S.seq M.slot)) (#state:G.erased M.snapshot)
requires idle_resources slot cp response bytes c slots pool state
requires pure (M.table_ok c slots pool /\ U32.v length <= S.length bytes)
returns result:option descriptor
ensures (match result with
  | None -> idle_resources slot cp response bytes c slots pool state
  | Some d -> pending slot cp d bytes c slots pool state ** pure (
      d.stream_id == id /\ d.data == response /\ d.length == length /\ d.fin == fin))
ensures pure (None? result <==>
  (forall (j:nat). j < U32.v c.M.cc_num /\ j < S.length slots ==>
    ((G.reveal state) (S.index slots j)).P.sc_id <> id))

fn inspect_pending (slot:send_slot) (cp:R.ref M.connection_context)
  (#d:G.erased descriptor) (#bytes:G.erased (S.seq U8.t))
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires pending slot cp d bytes c slots pool state
returns result:descriptor
ensures pending slot cp d bytes c slots pool state ** pure (result == d)

(* A modeled notification, not evidence that MsQuic has stopped reading.
   Caller must invoke matching completion/drop only after transport quiescence.
   Mismatch retains every resource; both truthful outcomes close the first
   matching active slot. No generation/replay or external callback proof here. *)
fn finish_send (slot:send_slot) (cp:R.ref M.connection_context)
  (completion_id:U64.t) (outcome:outcome)
  (#d:G.erased descriptor) (#bytes:G.erased (S.seq U8.t))
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires pending slot cp d bytes c slots pool state
returns accepted:bool
ensures pure (accepted <==> completion_id == d.stream_id)
ensures (if accepted then
  exists* (count:U32.t) (order:S.seq M.slot).
    R.pts_to slot None ** A.pts_to d.data bytes **
    connection_owned cp ({c with M.cc_num = count}) order pool state **
    pure (close_result c slots pool state d.stream_id count order)
  else pending slot cp d bytes c slots pool state)

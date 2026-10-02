module DNS.Migration.PulseSend
#lang-pulse

open Pulse.Lib.Pervasives
module A = Pulse.Lib.Array
module R = Pulse.Lib.Reference
module S = FStar.Seq
module G = FStar.Ghost
module U8 = FStar.UInt8
module U32 = FStar.UInt32
module U64 = FStar.UInt64
module M = DNS.Migration.PulseMultiplexer
module P = DNS.Migration.PulseStream

let pending (slot:send_slot) (cp:R.ref M.connection_context)
  (d:descriptor) (bytes:S.seq U8.t) (c:M.connection_context)
  (slots pool:S.seq M.slot) (state:M.snapshot) : slprop =
  R.pts_to slot (Some d) ** A.pts_to d.data bytes **
  connection_owned cp c slots pool state ** pure (
    M.table_ok c slots pool /\ U32.v d.length <= S.length bytes /\
    (exists (j:nat). j < U32.v c.M.cc_num /\ (state (S.index slots j)).P.sc_id == d.stream_id))

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
{
  let current = !cp;
  let found = M.find_stream cp id;
  if (U32.lt found current.M.cc_num) {
    let d = {stream_id = id; data = response; length = length; fin = fin};
    slot := Some d;
    rewrite A.pts_to response bytes as A.pts_to d.data bytes;
    fold pending slot cp d bytes c slots pool state;
    Some d
  } else {
    None
  }
}

fn inspect_pending (slot:send_slot) (cp:R.ref M.connection_context)
  (#d:G.erased descriptor) (#bytes:G.erased (S.seq U8.t))
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires pending slot cp d bytes c slots pool state
returns result:descriptor
ensures pending slot cp d bytes c slots pool state ** pure (result == d)
{
  unfold pending slot cp d bytes c slots pool state;
  let stored = !slot;
  fold pending slot cp d bytes c slots pool state;
  Some?.v stored
}

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
{
  unfold pending slot cp d bytes c slots pool state;
  let stored = !slot;
  let descriptor = Some?.v stored;
  (* Completion and drop intentionally have identical local cleanup. Neither
     value establishes that an external transport has released the pointer. *)
  if (U64.eq completion_id descriptor.stream_id) {
    let closed = M.close_stream cp descriptor.stream_id;
    assert (pure closed);
    slot := None;
    true
  } else {
    fold pending slot cp d bytes c slots pool state;
    false
  }
}

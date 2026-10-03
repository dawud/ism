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

open Pulse.Lib.Array
module SZ = FStar.SizeT
module T = DNS.QUIC.TableModel

let pending (slot:send_slot) (d:descriptor) (bytes:S.seq U8.t) : slprop =
  A.pts_to d.data bytes ** pure (U32.v d.length <= S.length bytes)

let reserved_connection (slot:send_slot) (cp:R.ref M.connection_context)
  (d:descriptor) (saved:P.stream_context) (c:M.connection_context)
  (slots pool:S.seq M.slot) (state:M.snapshot) : slprop =
  exists* (index:U32.t).
    R.pts_to slot (Some {send = d; index = index}) **
    connection_owned cp c slots pool state ** pure (
      M.table_ok c slots pool /\ U32.v index < U32.v c.M.cc_num /\
      S.index slots (U32.v index) == d.context /\
      state d.context == saved /\ saved.P.sc_id == d.stream_id)

let lemma_reserved_swap (slots:S.seq M.slot) (count reserved removed:nat)
  : Lemma
    (requires (count <= S.length slots /\ reserved < count /\ removed < count /\ reserved <> removed))
    (ensures (
      let next = if reserved = count - 1 then removed else reserved in
      next < count - 1 /\ S.index (SP.swap slots removed (count - 1)) next == S.index slots reserved)) = ()

let lemma_removed_absent (slots:S.seq M.slot) (count removed:nat)
  : Lemma
    (requires (T.distinct slots /\ count <= S.length slots /\ removed < count))
    (ensures (forall (j:nat). j < count - 1 ==>
      S.index (SP.swap slots removed (count - 1)) j =!= S.index slots removed)) = ()

(* Internal indexed close: preserves every current context value. The checked
   reservation cursor, not an ID search or a raw pointer comparison, chooses
   the context. No change to the extracted multiplexer API is needed. *)
fn close_index (cp:R.ref M.connection_context) (index:U32.t)
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires connection_owned cp c slots pool state
requires pure (M.table_ok c slots pool /\ U32.v index < U32.v c.M.cc_num)
ensures exists* (count:U32.t) (order:S.seq M.slot).
  connection_owned cp ({c with M.cc_num = count}) order pool state ** pure (
    M.table_ok c slots pool /\ U32.v index < U32.v c.M.cc_num /\
    count == U32.sub c.M.cc_num 1ul /\
    order == SP.swap slots (U32.v index) (U32.v c.M.cc_num - 1) /\
    M.table_ok ({c with M.cc_num = count}) order pool)
{
  let current = !cp;
  A.pts_to_len current.M.cc_active;
  let last = U32.sub current.M.cc_num 1ul;
  let removed = current.M.cc_active.(SZ.uint32_to_sizet index);
  let final = current.M.cc_active.(SZ.uint32_to_sizet last);
  current.M.cc_active.(SZ.uint32_to_sizet last) <- removed;
  current.M.cc_active.(SZ.uint32_to_sizet index) <- final;
  T.lemma_swap_distinct slots (U32.v index) (U32.v last);
  T.lemma_swap_contains slots (U32.v index) (U32.v last);
  cp := {current with M.cc_num = last};
}

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
{
  let current = !cp;
  let found = M.find_stream cp id;
  if (U32.lt found current.M.cc_num) {
    A.pts_to_len current.M.cc_active;
    let context = current.M.cc_active.(SZ.uint32_to_sizet found);
    let d = {stream_id = id; data = response; length = length; fin = fin; context = context};
    slot := Some {send = d; index = found};
    rewrite A.pts_to response bytes as A.pts_to d.data bytes;
    fold pending slot d bytes;
    fold reserved_connection slot cp d ((G.reveal state) context) c slots pool state;
    Some d
  } else {
    None
  }
}

fn inspect_pending (slot:send_slot) (cp:R.ref M.connection_context)
  (#d:G.erased descriptor) (#saved:G.erased P.stream_context)
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires reserved_connection slot cp d saved c slots pool state
returns result:descriptor
ensures reserved_connection slot cp d saved c slots pool state ** pure (result == d)
{
  unfold reserved_connection slot cp d saved c slots pool state;
  let stored = !slot;
  fold reserved_connection slot cp d saved c slots pool state;
  (Some?.v stored).send
}

fn find_while_pending (slot:send_slot) (cp:R.ref M.connection_context) (id:U64.t)
  (#d:G.erased descriptor) (#saved:G.erased P.stream_context)
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires reserved_connection slot cp d saved c slots pool state
returns result:U32.t
ensures reserved_connection slot cp d saved c slots pool state **
  pure (lookup_result c slots state id result)
{
  unfold reserved_connection slot cp d saved c slots pool state;
  let result = M.find_stream cp id;
  fold reserved_connection slot cp d saved c slots pool state;
  result
}

fn allocate_while_pending (slot:send_slot) (cp:R.ref M.connection_context) (id:U64.t)
  (#d:G.erased descriptor) (#saved:G.erased P.stream_context)
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires reserved_connection slot cp d saved c slots pool state
returns result:U32.t
ensures exists* (count:U32.t) (next:M.snapshot).
  reserved_connection slot cp d saved ({c with M.cc_num = count}) slots pool next **
  pure (allocation_result c slots pool state id result count next)
{
  unfold reserved_connection slot cp d saved c slots pool state;
  let result = M.allocate_stream cp id;
  with count next. assert connection_owned cp ({c with M.cc_num = count}) slots pool next;
  fold reserved_connection slot cp d saved ({c with M.cc_num = count}) slots pool next;
  result
}

fn close_other (slot:send_slot) (cp:R.ref M.connection_context) (id:U64.t)
  (#d:G.erased descriptor) (#saved:G.erased P.stream_context)
  (#c:G.erased M.connection_context) (#slots #pool:G.erased (S.seq M.slot))
  (#state:G.erased M.snapshot)
requires reserved_connection slot cp d saved c slots pool state
returns closed:bool
ensures exists* (count:U32.t) (order:S.seq M.slot).
  reserved_connection slot cp d saved ({c with M.cc_num = count}) order pool state **
  pure (other_close_result d c slots pool state id closed count order)
{
  unfold reserved_connection slot cp d saved c slots pool state;
  let stored = !slot;
  let reservation = Some?.v stored;
  let current = !cp;
  if (U64.eq id reservation.send.stream_id) {
    fold reserved_connection slot cp d saved ({c with M.cc_num = current.M.cc_num}) slots pool state;
    false
  } else {
    let found = M.find_stream cp id;
    if (U32.lt found current.M.cc_num) {
      let last = U32.sub current.M.cc_num 1ul;
      assert (pure (U32.v reservation.index <> U32.v found));
      close_index cp found;
      lemma_reserved_swap slots (U32.v current.M.cc_num) (U32.v reservation.index) (U32.v found);
      let index = (if U32.eq reservation.index last then found else reservation.index);
      slot := Some {send = reservation.send; index = index};
      rewrite R.pts_to slot (Some {send = reservation.send; index = index}) as
        R.pts_to slot (Some {send = d; index = index});
      fold reserved_connection slot cp d saved ({c with M.cc_num = last})
        (SP.swap slots (U32.v found) (U32.v last)) pool state;
      true
    } else {
      fold reserved_connection slot cp d saved ({c with M.cc_num = current.M.cc_num}) slots pool state;
      false
    }
  }
}

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
{
  unfold reserved_connection slot cp d saved c slots pool state;
  let stored = !slot;
  let reservation = Some?.v stored;
  if (U64.eq completion_id reservation.send.stream_id) {
    unfold pending slot d bytes;
    let current = !cp;
    close_index cp reservation.index;
    lemma_removed_absent slots (U32.v current.M.cc_num) (U32.v reservation.index);
    slot := None;
    true
  } else {
    fold reserved_connection slot cp d saved c slots pool state;
    false
  }
}

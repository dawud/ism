module DNS.QUIC.TableModel

(* Shared slot-permutation contract. Pointer identities are abstract here. *)
module S = FStar.Seq
module SP = FStar.Seq.Properties

let contains (#a:Type0) (slots:S.seq a) (p:a) : prop =
  exists (i:nat). i < S.length slots /\ S.index slots i == p

let distinct (#a:Type0) (slots:S.seq a) : prop =
  forall (i:nat) (j:nat). i < S.length slots /\ j < S.length slots /\ i <> j ==>
    S.index slots i =!= S.index slots j

let lemma_swap_distinct (#a:Type0) (slots:S.seq a)
  (i:nat{i < S.length slots}) (j:nat{j < S.length slots})
  : Lemma (distinct slots ==> distinct (SP.swap slots i j)) = ()

let lemma_swap_contains (#a:Type0) (slots:S.seq a)
  (i:nat{i < S.length slots}) (j:nat{j < S.length slots})
  : Lemma (forall p. contains slots p <==> contains (SP.swap slots i j) p) = ()

module DNS.QUIC.TableModel.Tests

module T = DNS.QUIC.TableModel
module S = FStar.Seq
module SP = FStar.Seq.Properties

let slots = S.cons 10 (S.cons 20 (S.cons 30 S.empty))

let close_keeps_removed_slot_available () : Lemma (
  T.distinct slots /\
  SP.swap slots 0 2 == S.cons 30 (S.cons 20 (S.cons 10 S.empty)) /\
  T.distinct (SP.swap slots 0 2) /\
  (forall p. T.contains slots p <==> T.contains (SP.swap slots 0 2) p)) =
  assert (T.distinct slots);
  T.lemma_swap_distinct slots 0 2;
  T.lemma_swap_contains slots 0 2;
  S.lemma_eq_intro (SP.swap slots 0 2) (S.cons 30 (S.cons 20 (S.cons 10 S.empty)));
  S.lemma_eq_elim (SP.swap slots 0 2) (S.cons 30 (S.cons 20 (S.cons 10 S.empty)))

let closing_last_slot_is_identity () : Lemma (SP.swap slots 2 2 == slots) =
  S.lemma_eq_intro (SP.swap slots 2 2) slots;
  S.lemma_eq_elim (SP.swap slots 2 2) slots

let duplicates_are_not_owned_slots () : Lemma (
  ~ (T.distinct (S.cons 10 (S.cons 10 S.empty)))) = ()

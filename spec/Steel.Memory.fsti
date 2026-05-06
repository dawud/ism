module Steel.Memory

open LowStar.Buffer

(* Trusted bootstrap adapter for the tiny Steel surface used by the current
   concurrency/cache scaffolds. pointer is an exact LowStar buffer alias, while
   vprop is erased to unit until real Steel permissions and invariants are
   integrated. Any proof that depends on vprop must remain listed as trusted
   boundary debt. *)
type pointer (a:Type) = buffer a
type vprop = unit

module EverCrypt.Helpers

open FStar.Bytes

(* Trusted bootstrap adapter for EverCrypt helper imports. The current
   DNS.Security.Context scaffold only needs the import path to typecheck; helper
   operations, key material invariants, and algorithm metadata must come from
   the real Everest dependency or a narrower documented adapter. *)

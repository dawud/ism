module LowParse.Low.Base

open LowStar.Buffer

(* Trusted bootstrap adapter for the LowParse surface currently used by the
   handwritten DNS parser. The parser combinator type is a placeholder until
   the real EverParse/LowParse dependency is wired in. The uint8_ptr alias is
   intentionally exact: callers reason about live LowStar buffers and lengths
   through LowStar.Buffer predicates in the consuming parser signatures. *)
type parser (a:Type) = unit
type uint8_ptr = buffer FStar.UInt8.t

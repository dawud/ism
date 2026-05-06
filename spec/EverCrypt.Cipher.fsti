module EverCrypt.Cipher

open LowStar.Buffer

(* Trusted bootstrap adapter for the EverCrypt cipher import. This local module
   currently exposes no cipher or TLS operations; DNS.Security.Handshake keeps
   the active client-hello validation model until miTLS/EverQuic or the real
   EverCrypt cipher interfaces are integrated. *)

module EverCrypt.Cipher

open LowStar.Buffer
open LowStar.Modifies
open FStar.HyperStack.ST

(* Trusted bootstrap adapter for the EverCrypt cipher/TLS import. The exported
   operation is a narrow ClientHello validation boundary until miTLS/EverQuic or
   the real EverCrypt cipher interfaces are integrated. A true result means the
   input range is an acceptable TLS ClientHello for the DNS-over-QUIC server
   policy; that protocol-authentication property remains trusted. *)

val validate_client_hello :
  input:buffer FStar.UInt8.t ->
  len:FStar.UInt32.t ->
  Stack bool
    (requires (fun h0 ->
      live h0 input /\
      FStar.UInt32.v len <= LowStar.Buffer.length input))
    (ensures (fun h0 _ h1 -> modifies_none h0 h1))

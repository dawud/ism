module EverCrypt.AEAD

open LowStar.Buffer
open FStar.Bytes

(* Trusted bootstrap adapter for the EverCrypt AEAD import. The exported
   operation is a narrow authentication/decryption boundary until the real
   EverCrypt AEAD interface is wired in. A true result means pt_buffer contains
   authenticated plaintext for the requested ciphertext range; that authenticity
   property remains trusted and must stay visible in docs/THREAT_MODEL.md. *)

val decrypt_authenticated :
  key:bytes ->
  iv:FStar.UInt8.t ->
  ciphertext:buffer FStar.UInt8.t ->
  ct_len:FStar.UInt32.t ->
  pt_buffer:buffer FStar.UInt8.t ->
  FStar.HyperStack.ST.ST bool
    (requires (fun h0 ->
      live h0 ciphertext /\
      live h0 pt_buffer /\
      FStar.UInt32.v ct_len <= LowStar.Buffer.length ciphertext /\
      FStar.UInt32.v ct_len <= LowStar.Buffer.length pt_buffer))
    (ensures (fun h0 _ h1 ->
      live h1 pt_buffer /\
      FStar.UInt32.v ct_len <= LowStar.Buffer.length pt_buffer))

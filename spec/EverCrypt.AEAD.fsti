module EverCrypt.AEAD

open LowStar.Buffer
open FStar.Bytes

(* Trusted bootstrap adapter for the EverCrypt AEAD import. This local module
   currently exposes no cryptographic operations; the active AEAD model lives at
   DNS.Security.Gateway.decrypt, which treats authentication as a trusted
   success/failure boundary until the real EverCrypt AEAD interface is wired in.
   Do not add proof obligations that depend on ciphertext authenticity without
   keeping the corresponding trust assumption visible in docs/THREAT_MODEL.md. *)

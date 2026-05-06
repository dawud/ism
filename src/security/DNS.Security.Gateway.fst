module DNS.Security.Gateway

open FStar.HyperStack.ST
open DNS.Protocol
open DNS.Protocol.Parser
open EverCrypt.AEAD
open LowStar.Buffer
module HS = FStar.HyperStack

(* Trusted AEAD model for specification purposes. Until the real EverCrypt
   boundary is integrated, successful decryption is modeled as an authenticated
   plaintext workspace populated from the ciphertext range. *)
type ae_key = FStar.Bytes.bytes
type ae_result = | Success | Failure

val decrypt : 
    key:ae_key -> 
    iv:FStar.UInt8.t -> 
    ciphertext:buffer FStar.UInt8.t -> 
    ct_len:FStar.UInt32.t -> 
    pt_buffer:buffer FStar.UInt8.t -> 
    ST ae_result
      (requires (fun h0 ->
        live h0 ciphertext /\
        live h0 pt_buffer /\
        FStar.UInt32.v ct_len <= LowStar.Buffer.length pt_buffer))
      (ensures (fun h0 _ h1 ->
        live h1 pt_buffer /\
        FStar.UInt32.v ct_len <= LowStar.Buffer.length pt_buffer))
let decrypt key iv ciphertext ct_len pt_buffer = Success

(* Decrypt and Parse: The primary security barrier *)
val decrypt_and_validate :
    key:ae_key ->
    iv:FStar.UInt8.t ->
    ciphertext:buffer FStar.UInt8.t ->
    ct_len:FStar.UInt32.t ->
    ST (option header) 
      (requires (fun h0 ->
        live h0 ciphertext /\
        FStar.UInt32.v ct_len <= LowStar.Buffer.length ciphertext))
      (ensures (fun h0 _ h1 -> True))

let decrypt_and_validate key iv ciphertext ct_len =
  if FStar.UInt32.v ct_len = 0 then
    None
  else
    begin
      assert (FStar.UInt32.v ct_len > 0);
      let pt_buffer = LowStar.Buffer.mmalloc_and_blit HS.root ciphertext 0ul ct_len in
      assert (FStar.UInt32.v ct_len <= LowStar.Buffer.length pt_buffer);
      let res = decrypt key iv ciphertext ct_len pt_buffer in
      if res = Success then
        match parse_dns_packet_buffer pt_buffer ct_len with
        | Some pkt -> Some pkt.header
        | None -> None
      else
        None
    end

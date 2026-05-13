module DNS.Security.Handshake

open FStar.HyperStack.ST
open EverCrypt.Cipher
open LowStar.Buffer
open LowStar.Modifies
open FStar.Bytes

(* State representing the TLS 1.3 Handshake progress *)
type hs_state =
  | WaitClientHello
  | WaitClientFinished
  | Connected

(* Trusted ClientHello validation model for specification purposes. Until the
   real TLS boundary is integrated, validation is delegated to the narrow
   EverCrypt.Cipher bootstrap adapter. *)
val verify_client_hello :
    input:buffer FStar.UInt8.t ->
    len:FStar.UInt32.t ->
    Stack bool
      (requires (fun h0 ->
        live h0 input /\
        FStar.UInt32.v len <= LowStar.Buffer.length input))
      (ensures (fun h0 _ h1 -> modifies_none h0 h1))

let verify_client_hello input len =
  validate_client_hello input len

(* Process an incoming CRYPTO frame from QUIC *)
val process_crypto_frame :
    st:hs_state ->
    input:buffer FStar.UInt8.t ->
    len:FStar.UInt32.t ->
    Stack hs_state
      (requires (fun h0 ->
        live h0 input /\
        FStar.UInt32.v len <= LowStar.Buffer.length input))
      (ensures (fun h0 r h1 -> modifies_none h0 h1))

let process_crypto_frame st input len =
  match st with
  | WaitClientHello ->
      if verify_client_hello input len then Connected else WaitClientHello
  | _ -> st 

module DNS.Security.Context

open EverCrypt.Helpers
open Spec.Agile.Cipher

(* We define the supported cipher suites for our modern-only server *)
type supported_alg =
  | AES128_GCM
  | CHACHA20_POLY1305

(* The connection context is stored in the 'Steel' heap for thread-safety *)
type crypto_context = {
  algo: supported_alg;
  static_secret: FStar.Bytes.bytes; // The server's private key
  epoch: FStar.UInt32.t;        // Tracks key rotations in QUIC
  is_handshake_complete: bool;
}

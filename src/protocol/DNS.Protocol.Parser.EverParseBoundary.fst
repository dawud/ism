module DNS.Protocol.Parser.EverParseBoundary

open DNS.Protocol
open DNS.Protocol.Parser

type parser_backend =
  | ReferenceBootstrap
  | EverParseGenerated

let active_parser_backend : parser_backend = ReferenceBootstrap

let everparse_generated_parser_available : bool = false

val parse_dns_packet_bytes_at_boundary :
  input:list FStar.UInt8.t ->
  Tot (option dns_packet)

let parse_dns_packet_bytes_at_boundary input =
  parse_dns_packet_bytes input

val validate_dns_packet_bytes_at_boundary :
  input:list FStar.UInt8.t ->
  Tot bool

let validate_dns_packet_bytes_at_boundary input =
  match parse_dns_packet_bytes_at_boundary input with
  | Some _ -> true
  | None -> false

val lemma_boundary_matches_reference :
  input:list FStar.UInt8.t ->
  Lemma (ensures (parse_dns_packet_bytes_at_boundary input ==
                  parse_dns_packet_bytes input))

let lemma_boundary_matches_reference input =
  ()

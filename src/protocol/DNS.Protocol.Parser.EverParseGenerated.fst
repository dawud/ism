module DNS.Protocol.Parser.EverParseGenerated

open DNS.Protocol
open DNS.Protocol.Parser
module L = FStar.List.Tot

type generated_parse_status =
  | GeneratedSubsetBoundary

let generated_parse_status_value : generated_parse_status = GeneratedSubsetBoundary

val parse_dns_packet_bytes_generated :
  input:list FStar.UInt8.t ->
  Tot (option dns_packet)

let parse_dns_packet_bytes_generated input =
  match parse_header_bytes input with
  | None -> None
  | Some (h, rest) ->
      if h.ancount <> 0us || h.nscount <> 0us || h.arcount <> 0us then
        None
      else
        let qd = FStar.UInt16.v h.qdcount in
        match parse_questions_bytes qd qd rest with
        | None -> None
        | Some (qs, tail) ->
            if L.length tail = 0 then
              Some {
                header = h;
                questions = qs;
                answers = [];
                authorities = [];
                additionals = [];
              }
            else
              None

val validate_dns_packet_bytes_generated :
  input:list FStar.UInt8.t ->
  Tot bool

let validate_dns_packet_bytes_generated input =
  match parse_dns_packet_bytes_generated input with
  | Some _ -> true
  | None -> false

val lemma_generated_matches_reference :
  input:list FStar.UInt8.t ->
  Lemma (ensures (parse_dns_packet_bytes_generated input ==
                  parse_dns_packet_bytes input))

let lemma_generated_matches_reference input =
  ()

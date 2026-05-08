module DNS.Protocol.Parser.EverParseAdapter

open DNSProtocol

type generated_validator_link_status =
  | GeneratedDnsProtocolValidatorsLinked

let generated_validator_link_status_value : generated_validator_link_status =
  GeneratedDnsProtocolValidatorsLinked

let generated_dns_header_validator_linked : bool = true

let generated_dns_root_question_validator_linked : bool = true

let generated_dns_single_label_question_validator_linked : bool = true

let generated_dns_header_validator = DNSProtocol.validate__dns_header

let generated_dns_root_question_validator =
  DNSProtocol.validate__dns_root_question

let generated_dns_single_label_question_validator label_length =
  DNSProtocol.validate__dns_single_label_question label_length

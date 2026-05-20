module DNS.Protocol.Parser.EverParseAdapter

open DNSProtocol

type generated_validator_link_status =
  | GeneratedDnsProtocolValidatorsLinked

let generated_validator_link_status_value : generated_validator_link_status =
  GeneratedDnsProtocolValidatorsLinked

let generated_dns_header_validator_linked : bool = true

let generated_dns_root_question_validator_linked : bool = true

let generated_dns_single_label_question_validator_linked : bool = true

let generated_dns_two_label_question_validator_linked : bool = true

let generated_dns_uncompressed_question_validator_linked : bool = true

let generated_dns_uncompressed_question_answer_packet_validator_linked : bool = true

let generated_dns_uncompressed_question_a_answer_packet_validator_linked : bool = true

let generated_dns_uncompressed_question_aaaa_answer_packet_validator_linked : bool = true

let generated_dns_uncompressed_question_name_rdata_answer_packet_validator_linked : bool = true

let generated_dns_uncompressed_question_compressed_name_rdata_answer_packet_validator_linked : bool = true

let generated_dns_uncompressed_question_mx_answer_packet_validator_linked : bool = true

let generated_dns_uncompressed_question_compressed_mx_answer_packet_validator_linked : bool = true

let generated_dns_uncompressed_question_soa_answer_packet_validator_linked : bool = true

let generated_dns_uncompressed_question_srv_answer_packet_validator_linked : bool = true

let generated_dns_uncompressed_question_txt_answer_packet_validator_linked : bool = true

let generated_dns_uncompressed_question_compressed_answer_name_packet_validator_linked : bool = true

let generated_dns_opt_additional_packet_validator_linked : bool = true

let generated_dns_uncompressed_question_opt_additional_packet_validator_linked : bool = true

let generated_dns_header_validator = DNSProtocol.validate__dns_header

let generated_dns_root_question_validator =
  DNSProtocol.validate__dns_root_question

let generated_dns_single_label_question_validator label_length =
  DNSProtocol.validate__dns_single_label_question label_length

let generated_dns_two_label_question_validator first_label_length second_label_length =
  DNSProtocol.validate__dns_two_label_question first_label_length second_label_length

let generated_dns_uncompressed_question_validator qname_length =
  DNSProtocol.validate__dns_uncompressed_question qname_length

let generated_dns_uncompressed_question_answer_packet_validator qname_length rr_name_length rdata_length =
  DNSProtocol.validate__dns_uncompressed_question_answer_packet qname_length rr_name_length rdata_length

let generated_dns_uncompressed_question_a_answer_packet_validator qname_length rr_name_length =
  DNSProtocol.validate__dns_uncompressed_question_a_answer_packet qname_length rr_name_length

let generated_dns_uncompressed_question_aaaa_answer_packet_validator qname_length rr_name_length =
  DNSProtocol.validate__dns_uncompressed_question_aaaa_answer_packet qname_length rr_name_length

let generated_dns_uncompressed_question_name_rdata_answer_packet_validator
    qname_length rr_name_length rdata_name_length expected_rtype =
  DNSProtocol.validate__dns_uncompressed_question_name_rdata_answer_packet
    qname_length
    rr_name_length
    rdata_name_length
    expected_rtype

let generated_dns_uncompressed_question_compressed_name_rdata_answer_packet_validator
    qname_length rr_name_length expected_rtype =
  DNSProtocol.validate__dns_uncompressed_question_compressed_name_rdata_answer_packet
    qname_length
    rr_name_length
    expected_rtype

let generated_dns_uncompressed_question_mx_answer_packet_validator
    qname_length rr_name_length exchange_name_length =
  DNSProtocol.validate__dns_uncompressed_question_mx_answer_packet
    qname_length
    rr_name_length
    exchange_name_length

let generated_dns_uncompressed_question_compressed_mx_answer_packet_validator
    qname_length rr_name_length =
  DNSProtocol.validate__dns_uncompressed_question_compressed_mx_answer_packet
    qname_length
    rr_name_length

let generated_dns_uncompressed_question_soa_answer_packet_validator
    qname_length rr_name_length mname_length rname_length =
  DNSProtocol.validate__dns_uncompressed_question_soa_answer_packet
    qname_length
    rr_name_length
    mname_length
    rname_length

let generated_dns_uncompressed_question_srv_answer_packet_validator
    qname_length rr_name_length target_name_length =
  DNSProtocol.validate__dns_uncompressed_question_srv_answer_packet
    qname_length
    rr_name_length
    target_name_length

let generated_dns_uncompressed_question_txt_answer_packet_validator
    qname_length rr_name_length rdata_length =
  DNSProtocol.validate__dns_uncompressed_question_txt_answer_packet
    qname_length
    rr_name_length
    rdata_length

let generated_dns_uncompressed_question_compressed_answer_name_packet_validator
    qname_length rdata_length =
  DNSProtocol.validate__dns_uncompressed_question_compressed_answer_name_packet
    qname_length
    rdata_length

let generated_dns_opt_additional_packet_validator option_payload_length =
  DNSProtocol.validate__dns_opt_additional_packet option_payload_length

let generated_dns_uncompressed_question_opt_additional_packet_validator
    qname_length option_payload_length =
  DNSProtocol.validate__dns_uncompressed_question_opt_additional_packet
    qname_length
    option_payload_length

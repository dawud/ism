module DNS.Protocol

open FStar.UInt16
open DNS.Name

(* Refinement types for 4-bit fields *)
type u4 = n:FStar.UInt16.t{FStar.UInt16.v n <= 15}

type dns_flags = {
  qr:     bool;
  opcode: u4;
  aa:     bool;
  tc:     bool;
  rd:     bool;
  ra:     bool;
  z:      bool;   (* Reserved *)
  ad:     bool;
  cd:     bool;
  rcode:  u4;
}

type header = {
  id:      FStar.UInt16.t;
  flags:   dns_flags;
  qdcount: FStar.UInt16.t;
  ancount: FStar.UInt16.t;
  nscount: FStar.UInt16.t;
  arcount: FStar.UInt16.t;
}

type qtype =
  | A          | AAAA       | APL        | CAA
  | CDNSKEY    | CDS        | CERT       | CNAME
  | CSYNC      | DHCID      | DLV        | DNAME
  | DNSKEY     | DS         | EUI48      | EUI64
  | HINFO      | HIP        | HTTPS      | IPSECKEY
  | KX         | LOC        | MX         | NAPTR
  | NS         | NSEC3      | NSEC3PARAM | OPT
  | PTR        | RP         | RRSIG      | SMIMEA
  | SOA        | SSHFP      | SVCB       | SRV
  | TA         | TKEY       | TLSA       | TSIG
  | TXT        | URI        | ZONEMD
  | UNKNOWN    of FStar.UInt16.t

type question = {
  qname:  qname;
  qtype:  qtype;
  qclass: FStar.UInt16.t; (* Standard is 0x0001 (IN) *)
}

type resource_record = {
  name:   qname;
  rtype:  qtype;
  rclass: FStar.UInt16.t;
  ttl:    FStar.UInt32.t;
  rdlen:  FStar.UInt16.t;
  rdata:  FStar.Bytes.bytes;
}

type dns_packet = {
  header:      header;
  questions:   list question;
  answers:     list resource_record;
  authorities: list resource_record;
  additionals: list resource_record;
}

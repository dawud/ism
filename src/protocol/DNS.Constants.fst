module DNS.Constants

open FStar.UInt16
open DNS.Protocol

(* Mapping from Sum Type to Wire Format (Serialization) *)
let qtype_to_u16 (t: qtype) : FStar.UInt16.t =
  match t with
  | A          -> 1us     | NS         -> 2us
  | CNAME      -> 5us     | SOA        -> 6us
  | PTR        -> 12us    | HINFO      -> 13us
  | MX         -> 15us    | TXT        -> 16us
  | RP         -> 17us    | AAAA       -> 28us
  | LOC        -> 29us    | SRV        -> 33us
  | NAPTR      -> 35us    | KX         -> 36us
  | CERT       -> 37us    | DNAME      -> 39us
  | OPT        -> 41us    | APL        -> 42us
  | DS         -> 43us    | SSHFP      -> 44us
  | IPSECKEY   -> 45us    | RRSIG      -> 46us
  | DNSKEY     -> 48us    | DHCID      -> 49us
  | NSEC3      -> 50us    | NSEC3PARAM -> 51us
  | TLSA       -> 52us    | SMIMEA     -> 53us
  | HIP        -> 55us    | CDS        -> 59us
  | CDNSKEY    -> 60us    | CSYNC      -> 62us
  | ZONEMD     -> 63us    | SVCB       -> 64us
  | HTTPS      -> 65us    | EUI48      -> 108us
  | EUI64      -> 109us   | TKEY       -> 249us
  | TSIG       -> 250us   | URI        -> 256us
  | CAA        -> 257us   | TA         -> 32768us
  | DLV        -> 32769us | UNKNOWN n  -> n

(* Mapping from Wire Format to Sum Type (Parsing) *)
let u16_to_qtype (n: FStar.UInt16.t) : qtype =
  if n = 1us     then A          else if n = 2us     then NS
  else if n = 5us     then CNAME      else if n = 6us     then SOA
  else if n = 12us    then PTR        else if n = 13us    then HINFO
  else if n = 15us    then MX         else if n = 16us    then TXT
  else if n = 17us    then RP         else if n = 28us    then AAAA
  else if n = 29us    then LOC        else if n = 33us    then SRV
  else if n = 35us    then NAPTR      else if n = 36us    then KX
  else if n = 37us    then CERT       else if n = 39us    then DNAME
  else if n = 41us    then OPT        else if n = 42us    then APL
  else if n = 43us    then DS         else if n = 44us    then SSHFP
  else if n = 45us    then IPSECKEY   else if n = 46us    then RRSIG
  else if n = 48us    then DNSKEY     else if n = 49us    then DHCID
  else if n = 50us    then NSEC3      else if n = 51us    then NSEC3PARAM
  else if n = 52us    then TLSA       else if n = 53us    then SMIMEA
  else if n = 55us    then HIP        else if n = 59us    then CDS
  else if n = 60us    then CDNSKEY    else if n = 62us    then CSYNC
  else if n = 63us    then ZONEMD     else if n = 64us    then SVCB
  else if n = 65us    then HTTPS      else if n = 108us   then EUI48
  else if n = 109us   then EUI64      else if n = 249us   then TKEY
  else if n = 250us   then TSIG       else if n = 256us   then URI
  else if n = 257us   then CAA        else if n = 32768us then TA
  else if n = 32769us then DLV        else UNKNOWN n

module DNS.RCode

open FStar.UInt16

type rcode =
  | NoError    // 0: No Error
  | FormErr    // 1: Format Error (Parser rejected)
  | ServFail   // 2: Server Failure (Internal verified logic error)
  | NXDomain   // 3: Non-Existent Domain
  | NotImp     // 4: Not Implemented (Modern only, so we reject old methods)
  | Refused    // 5: Query Refused (Policy/ACL block)
  | YXDomain   // 6: Name Exists when it should not
  | YXRRSet    // 7: RR Set Exists when it should not
  | NXRRSet    // 8: RR Set that should exist does not
  | NotAuth    // 9: Server Not Authoritative for zone
  | NotZone    // 10: Name not contained in zone
  | DSOTYPENI  // 11: DSO-TYPE Not Implemented
  | BadVers    // 16: Bad OPT Version (EDNS0)
  | UnknownR   of (n:FStar.UInt16.t{FStar.UInt16.v n <= 15})

(* Mapping to the 4-bit wire format *)
(* Note: 16 (BadVers) is handled by EDNS0 and uses 0 in the 4-bit field. *)
let rcode_to_u4 (r: rcode) : (n:FStar.UInt16.t{FStar.UInt16.v n <= 15}) =
  match r with
  | NoError   -> 0us   | FormErr   -> 1us
  | ServFail  -> 2us   | NXDomain  -> 3us
  | NotImp    -> 4us   | Refused   -> 5us
  | YXDomain  -> 6us   | YXRRSet   -> 7us
  | NXRRSet   -> 8us   | NotAuth   -> 9us
  | NotZone   -> 10us  | DSOTYPENI -> 11us
  | BadVers   -> 0us   | UnknownR n -> n

type dns_result =
  | Success of list DNS.Protocol.resource_record
  | Error   of rcode

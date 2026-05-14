#include <stdbool.h>

#include "DNS_Protocol.h"

bool ism_smoke_protocol_qtype(void)
{
  DNS_Protocol_qtype qtype = { .tag = DNS_Protocol_A, ._0 = 0 };

  return DNS_Protocol_uu___is_A(qtype);
}

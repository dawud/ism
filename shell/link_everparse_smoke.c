#include <stdbool.h>
#include <stdint.h>

#include "DNSProtocolWrapper.h"

void DNSProtocolEverParseError(const char *StructName, const char *FieldName, const char *Reason)
{
  (void)StructName;
  (void)FieldName;
  (void)Reason;
}

bool ism_smoke_everparse_header(void)
{
  uint8_t header[12] = {0};

  return DnsprotocolCheckDnsHeader(header, sizeof header) != 0;
}

#include <stdbool.h>

bool ism_smoke_everparse_header(void);
bool ism_smoke_protocol_qtype(void);

int main(void)
{
  if (!ism_smoke_everparse_header() || !ism_smoke_protocol_qtype())
  {
    return 1;
  }

  return 0;
}

#include <stdbool.h>

bool ism_smoke_everparse_header(void);
bool ism_smoke_protocol_qtype(void);
bool ism_smoke_shell_boundary(void);
bool ism_smoke_shell_response_boundary(void);
bool ism_smoke_shell_scaffold(void);

int main(void)
{
  if (!ism_smoke_everparse_header() ||
      !ism_smoke_protocol_qtype() ||
      !ism_smoke_shell_boundary() ||
      !ism_smoke_shell_response_boundary() ||
      !ism_smoke_shell_scaffold())
  {
    return 1;
  }

  return 0;
}

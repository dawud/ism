#include <stdbool.h>

bool ism_smoke_everparse_header(void);
bool ism_smoke_protocol_qtype(void);
bool ism_smoke_shell_boundary(void);
bool ism_smoke_shell_response_boundary(void);
bool ism_smoke_shell_scaffold(void);
bool ism_smoke_msquic_adapter(void);
bool ism_smoke_event_queue(void);

int main(void)
{
  if (!ism_smoke_everparse_header() ||
      !ism_smoke_protocol_qtype() ||
      !ism_smoke_shell_boundary() ||
      !ism_smoke_shell_response_boundary() ||
      !ism_smoke_shell_scaffold() ||
      !ism_smoke_msquic_adapter() ||
      !ism_smoke_event_queue())
  {
    return 1;
  }

  return 0;
}

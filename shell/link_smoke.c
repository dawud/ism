#include <stdbool.h>
#include <stdio.h>

bool ism_smoke_everparse_header(void);
bool ism_smoke_protocol_qtype(void);
bool ism_smoke_shell_boundary(void);
bool ism_smoke_shell_response_boundary(void);
bool ism_smoke_shell_scaffold(void);
bool ism_smoke_msquic_adapter(void);
bool ism_smoke_msquic_runtime(void);
bool ism_smoke_event_queue(void);
bool ism_smoke_proof_audit(void);

int main(void)
{
  const struct { const char *name; bool (*run)(void); } checks[] = {
    {"everparse", ism_smoke_everparse_header},
    {"protocol", ism_smoke_protocol_qtype},
    {"shell boundary", ism_smoke_shell_boundary},
    {"response boundary", ism_smoke_shell_response_boundary},
    {"shell scaffold", ism_smoke_shell_scaffold},
    {"MsQuic adapter", ism_smoke_msquic_adapter},
    {"MsQuic runtime", ism_smoke_msquic_runtime},
    {"event queue", ism_smoke_event_queue},
    {"proof audit regressions", ism_smoke_proof_audit}
  };
  for (size_t i = 0; i < sizeof checks / sizeof checks[0]; ++i)
  {
    if (!checks[i].run())
    {
      fprintf(stderr, "Smoke check failed: %s\n", checks[i].name);
      return 1;
    }
  }

  return 0;
}

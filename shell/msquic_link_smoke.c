#include "msquic.h"

int
main(void)
{
  const QUIC_API_TABLE *api = 0;
  QUIC_STATUS status = MsQuicOpen2(&api);

  if (QUIC_FAILED(status) || api == 0)
  {
    return 1;
  }

  MsQuicClose(api);
  return 0;
}

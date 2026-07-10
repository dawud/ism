#include "msquic.h"

#include <stddef.h>

static QUIC_STATUS QUIC_API
ism_msquic_lifecycle_listener_callback(
  HQUIC listener,
  void *context,
  QUIC_LISTENER_EVENT *event
)
{
  (void)listener;
  (void)context;
  (void)event;

  return QUIC_STATUS_SUCCESS;
}

int
main(void)
{
  const QUIC_API_TABLE *api = 0;
  HQUIC registration = 0;
  HQUIC configuration = 0;
  HQUIC listener = 0;
  uint8_t alpn_bytes[] = { 'd', 'o', 'q' };
  const QUIC_REGISTRATION_CONFIG registration_config = {
    "ism-msquic-lifecycle-smoke",
    QUIC_EXECUTION_PROFILE_LOW_LATENCY
  };
  const QUIC_BUFFER alpn = {
    sizeof(alpn_bytes),
    alpn_bytes
  };
  int result = 1;

  if (QUIC_FAILED(MsQuicOpen2(&api)) || api == 0)
  {
    return result;
  }

  if (QUIC_FAILED(api->RegistrationOpen(
        &registration_config,
        &registration
      )) ||
      registration == 0)
  {
    goto cleanup;
  }

  if (QUIC_FAILED(api->ConfigurationOpen(
        registration,
        &alpn,
        1,
        0,
        0,
        0,
        &configuration
      )) ||
      configuration == 0)
  {
    goto cleanup;
  }

  if (QUIC_FAILED(api->ListenerOpen(
        registration,
        ism_msquic_lifecycle_listener_callback,
        0,
        &listener
      )) ||
      listener == 0)
  {
    goto cleanup;
  }

  result = 0;

cleanup:
  if (listener != 0)
  {
    api->ListenerClose(listener);
  }

  if (configuration != 0)
  {
    api->ConfigurationClose(configuration);
  }

  if (registration != 0)
  {
    api->RegistrationClose(registration);
  }

  MsQuicClose(api);
  return result;
}

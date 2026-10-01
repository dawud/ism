#ifndef ISM_PULSE_PHASE_DECODE_H
#define ISM_PULSE_PHASE_DECODE_H

/* Include only after this translation unit's candidate generated header. */
#include "ism_pulse_stream.h"
#include <stdbool.h>

static inline bool ism_pulse_decode_phase(ism_pulse_phase in, DNS_QUIC_StreamModel_stream_phase *out)
{
  *out = (DNS_QUIC_StreamModel_stream_phase){ .tag = DNS_QUIC_StreamModel_Done };
  switch (in.tag) {
    case ISM_PULSE_LENGTH:
      out->tag = DNS_QUIC_StreamModel_ReadingLength;
      return true;
    case ISM_PULSE_LENGTH_HIGH:
      out->tag = DNS_QUIC_StreamModel_ReadingLengthHigh;
      out->case_ReadingLengthHigh = in.high;
      return true;
    case ISM_PULSE_BODY:
      if (in.expected > ISM_PULSE_MESSAGE_CAPACITY) return false;
      out->tag = DNS_QUIC_StreamModel_ReadingMessage;
      out->case_ReadingMessage.expected = in.expected;
      out->case_ReadingMessage.current = in.current;
      return true;
    case ISM_PULSE_AWAITING_FIN:
      if (in.expected > ISM_PULSE_MESSAGE_CAPACITY) return false;
      out->tag = DNS_QUIC_StreamModel_AwaitingFin;
      out->case_AwaitingFin = in.expected;
      return true;
    case ISM_PULSE_PROCESSING:
      if (in.expected > ISM_PULSE_MESSAGE_CAPACITY) return false;
      out->tag = DNS_QUIC_StreamModel_Processing;
      out->case_Processing = in.expected;
      return true;
    case ISM_PULSE_DONE:
      return true;
    default:
      return false;
  }
}

#endif

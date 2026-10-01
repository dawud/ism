#ifndef ISM_PULSE_TABLE_ADAPTER_H
#define ISM_PULSE_TABLE_ADAPTER_H

#include "ism_shell.h"

/* Serialized, live embedded shell storage. No context/message addresses move.
 * Close changes table/count only; caller must immediately synchronize active
 * flags/reset retired slots before another operation or callback can observe it. */
DNS_QUIC_StreamMapping_stream_context *ism_pulse_table_find(ism_shell_connection *conn, uint64_t id);
DNS_QUIC_StreamMapping_stream_context *ism_pulse_table_open(ism_shell_connection *conn, uint64_t id);
uint8_t ism_pulse_table_close(ism_shell_connection *conn, uint64_t id);

#endif

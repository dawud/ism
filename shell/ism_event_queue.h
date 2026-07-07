#ifndef ISM_EVENT_QUEUE_H
#define ISM_EVENT_QUEUE_H

#include <stdbool.h>
#include <stdint.h>

#include "msquic_adapter.h"

typedef enum ism_shell_event_kind_e
{
  ISM_SHELL_EVENT_AUTHENTICATED_STREAM_BYTES = 1,
  ISM_SHELL_EVENT_READY_RESPONSE = 2,
  ISM_SHELL_EVENT_SEND_COMPLETE = 3,
  ISM_SHELL_EVENT_STREAM_RESET = 4
}
ism_shell_event_kind;

typedef struct ism_shell_event_s
{
  ism_shell_event_kind kind;
  uint64_t stream_id;
  uint8_t *data;
  uint32_t len;
  bool dropped;
}
ism_shell_event;

typedef struct ism_shell_event_queue_s
{
  ism_shell_event *events;
  uint32_t capacity;
  uint32_t head;
  uint32_t count;
}
ism_shell_event_queue;

void
ism_shell_event_queue_init(
  ism_shell_event_queue *queue,
  ism_shell_event *events,
  uint32_t capacity
);

uint32_t
ism_shell_event_queue_len(const ism_shell_event_queue *queue);

bool
ism_shell_event_queue_enqueue_authenticated_stream_bytes(
  ism_shell_event_queue *queue,
  uint64_t stream_id,
  uint8_t *data,
  uint32_t len
);

bool
ism_shell_event_queue_enqueue_ready_response(
  ism_shell_event_queue *queue,
  uint64_t stream_id
);

bool
ism_shell_event_queue_enqueue_send_complete(
  ism_shell_event_queue *queue,
  uint64_t stream_id,
  uint32_t response_len,
  bool dropped
);

bool
ism_shell_event_queue_enqueue_stream_reset(
  ism_shell_event_queue *queue,
  uint64_t stream_id
);

bool
ism_shell_event_queue_dequeue(
  ism_shell_event_queue *queue,
  ism_shell_event *event
);

bool
ism_shell_event_queue_dispatch_one(
  ism_shell_event_queue *queue,
  ism_msquic_adapter *adapter
);

uint32_t
ism_shell_event_queue_dispatch_all(
  ism_shell_event_queue *queue,
  ism_msquic_adapter *adapter,
  uint32_t max_events
);

#endif /* ISM_EVENT_QUEUE_H */

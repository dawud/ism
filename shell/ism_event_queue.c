#include "ism_event_queue.h"

#include <stddef.h>

static bool
ism_shell_event_queue_has_storage(const ism_shell_event_queue *queue)
{
  return queue != NULL && queue->events != NULL && queue->capacity > 0U;
}

static bool
ism_shell_event_queue_enqueue(
  ism_shell_event_queue *queue,
  ism_shell_event event
)
{
  if (!ism_shell_event_queue_has_storage(queue) ||
      queue->count >= queue->capacity)
  {
    return false;
  }

  uint32_t tail = queue->head + queue->count;
  if (tail >= queue->capacity)
  {
    tail -= queue->capacity;
  }

  queue->events[tail] = event;
  queue->count++;
  return true;
}

void
ism_shell_event_queue_init(
  ism_shell_event_queue *queue,
  ism_shell_event *events,
  uint32_t capacity
)
{
  if (queue == NULL)
  {
    return;
  }

  queue->events = events;
  queue->capacity = capacity;
  queue->head = 0U;
  queue->count = 0U;
}

uint32_t
ism_shell_event_queue_len(const ism_shell_event_queue *queue)
{
  if (queue == NULL)
  {
    return 0U;
  }

  return queue->count;
}

bool
ism_shell_event_queue_enqueue_authenticated_stream_bytes(
  ism_shell_event_queue *queue,
  uint64_t stream_id,
  uint8_t *data,
  uint32_t len
)
{
  if (data == NULL && len > 0U)
  {
    return false;
  }

  return ism_shell_event_queue_enqueue(queue, (ism_shell_event){
    .kind = ISM_SHELL_EVENT_AUTHENTICATED_STREAM_BYTES,
    .stream_id = stream_id,
    .data = data,
    .len = len,
    .dropped = false
  });
}

bool
ism_shell_event_queue_enqueue_ready_response(
  ism_shell_event_queue *queue,
  uint64_t stream_id
)
{
  return ism_shell_event_queue_enqueue(queue, (ism_shell_event){
    .kind = ISM_SHELL_EVENT_READY_RESPONSE,
    .stream_id = stream_id,
    .data = NULL,
    .len = 0U,
    .dropped = false
  });
}

bool
ism_shell_event_queue_enqueue_send_complete(
  ism_shell_event_queue *queue,
  uint64_t stream_id,
  uint32_t response_len,
  bool dropped
)
{
  return ism_shell_event_queue_enqueue(queue, (ism_shell_event){
    .kind = ISM_SHELL_EVENT_SEND_COMPLETE,
    .stream_id = stream_id,
    .data = NULL,
    .len = response_len,
    .dropped = dropped
  });
}

bool
ism_shell_event_queue_dequeue(
  ism_shell_event_queue *queue,
  ism_shell_event *event
)
{
  if (!ism_shell_event_queue_has_storage(queue) ||
      event == NULL ||
      queue->count == 0U)
  {
    return false;
  }

  *event = queue->events[queue->head];
  queue->head++;
  if (queue->head >= queue->capacity)
  {
    queue->head = 0U;
  }
  queue->count--;
  return true;
}

bool
ism_shell_event_queue_dispatch_one(
  ism_shell_event_queue *queue,
  ism_msquic_adapter *adapter
)
{
  ism_shell_event event;

  if (adapter == NULL ||
      !ism_shell_event_queue_dequeue(queue, &event))
  {
    return false;
  }

  switch (event.kind)
  {
    case ISM_SHELL_EVENT_AUTHENTICATED_STREAM_BYTES:
    {
      uint8_t phase =
        ism_shell_dispatch_authenticated_stream_data(
          &adapter->connection,
          event.stream_id,
          event.data,
          event.len
        );

      if (phase == 2U)
      {
        return ism_msquic_adapter_prepare_ready_response(
          adapter,
          event.stream_id
        ) > 0U;
      }

      return true;
    }

    case ISM_SHELL_EVENT_READY_RESPONSE:
      (void)ism_msquic_adapter_prepare_ready_response(
        adapter,
        event.stream_id
      );
      return true;

    case ISM_SHELL_EVENT_SEND_COMPLETE:
      return ism_msquic_adapter_on_send_complete(
        adapter,
        event.stream_id,
        event.len,
        event.dropped
      );

    default:
      return false;
  }
}

uint32_t
ism_shell_event_queue_dispatch_all(
  ism_shell_event_queue *queue,
  ism_msquic_adapter *adapter,
  uint32_t max_events
)
{
  uint32_t dispatched = 0U;

  while (dispatched < max_events &&
         ism_shell_event_queue_len(queue) > 0U)
  {
    if (!ism_shell_event_queue_dispatch_one(queue, adapter))
    {
      break;
    }

    dispatched++;
  }

  return dispatched;
}

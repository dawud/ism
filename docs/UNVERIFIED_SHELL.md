# Unverified Shell Boundary

This document defines the contract for the C shell that surrounds the verified
DNS-over-QUIC core. The shell is trusted code: it is allowed to perform OS,
QUIC, TLS, allocation, and scheduling work that is not yet verified, but it must
cross into the F*/Low* core only through narrow, documented entry points.

## Scope

The shell owns:

- POSIX socket setup, polling, reads, writes, and shutdown.
- QUIC/TLS stack integration, packet I/O, connection dispatch, stream event
  delivery, recovery, congestion control, and flow-control behavior.
- Thread creation, worker scheduling, timers, signal handling, and process
  lifecycle.
- Allocation and release of host-side buffers before they are handed to Low*.
- FFI glue between generated C, MsQuic as the preferred maintained QUIC/TLS
  stack, and the OS.

The shell must not implement DNS parsing, cache policy, bailiwick validation,
zone lookup semantics, CNAME chasing, or response-policy decisions. Those
belong in verified modules or explicitly documented trusted adapters.

## Ingress Contract

For every received QUIC stream fragment, the shell must provide a live
`LowStar.Buffer.buffer FStar.UInt8.t` and a length satisfying the verified
callee precondition:

- `live h0 buffer`
- `FStar.UInt32.v len <= LowStar.Buffer.length buffer`
- any callee-specific disjointness and capacity requirements

The preferred C-facing MsQuic ingress call is:

- `DNS.ShellBoundary.dispatch_authenticated_stream_data`

The current C shell scaffold and MsQuic-shaped adapter are:

- `shell/ism_shell.c`
- `shell/msquic_adapter.c`
- `shell/ism_event_queue.c`

The preferred verified model-level dispatcher remains:

- `DNS.ShellScheduler.dispatch_shell_event`

The shell may call verified boundary functions only when their preconditions are
established by construction or checked before the call:

- `DNS.ShellScheduler.dispatch_shell_event`
- `DNS.ShellBoundary.dispatch_authenticated_stream_data`
- `DNS.ShellResponseBoundary.prepare_response_send_for_stream`
- `DNS.ShellResponseBoundary.prepare_doq_response_send_for_stream`
- `DNS.ShellResponseBoundary.complete_response_send_for_stream`
- `DNS.Worker.Minimal.prepare_worker_minimal_error_response_send`
- `DNS.Worker.Minimal.prepare_worker_empty_noerror_response_send`
- `DNS.Worker.Minimal.prepare_worker_validated_minimal_response_send`
- `DNS.QUIC.StreamMapping.handle_stream_data`
- `DNS.QUIC.Multiplexer.find_stream`
- `DNS.Worker.worker_loop`

`DNS.ShellBoundary.dispatch_authenticated_stream_data` is included in the
`make c-link-smoke` generated C boundary harness, and
`DNS.ShellBoundary.process_ready_stream_for_response` covers minimal worker
error-response construction for an already-processing stream through
`DNS.Worker.Minimal`. `DNS.ShellBoundary.process_ready_stream_for_empty_response`
covers the same already-processing stream shape for a header-only empty NOERROR
response that preserves the request ID and selected request flags. Both helpers
keep the linked shell ABI away from the full list-backed worker/parser/zone
path.
`DNS.ShellBoundary.process_ready_stream_for_validated_minimal_response` is the
preferred narrow production-facing helper: it validates an uncompressed
question-only request through the generated EverParse runtime boundary, returns
a zero-answer NOERROR response that echoes the validated question when
accepted, and returns the minimal FORMERR response when rejected.
`DNS.ShellBoundary` also exposes C-shaped scheduler helper wrappers for
authenticated ingress, minimal worker response construction, and
send-completion/drop cleanup without exposing the rich F* `shell_event` union.
`DNS.ShellResponseBoundary` covers generated C response send
handoff/completion, including a DoQ egress helper that writes the two-octet DNS
message length prefix into a caller-owned stream buffer before the shell sends
bytes through MsQuic. `shell/ism_shell.c` owns a fixed-capacity
connection/stream table over those generated ABIs for local scaffold testing.
`shell/msquic_adapter.c` is a MsQuic-shaped callback adapter over that scaffold:
it bridges fake callback-shaped authenticated stream bytes through the
scheduler helper wrappers, prepares generated-validator-backed ready responses
into a caller-owned buffer, wraps those DNS response bytes in a caller-owned DoQ
stream buffer, sends the framed bytes, and leaves send-completion cleanup as a
separate callback. It does not include MsQuic headers or own sockets, real
MsQuic callbacks, polling, timers, dynamic allocation, or production event-loop
integration. `shell/ism_event_queue.c` adds a fixed-capacity ring for
shell-selected authenticated-ingress, ready-response, and send-completion
events; when authenticated ingress reaches `Processing`, the queue dispatcher
services the ready response immediately instead of enqueueing a derived
ready-response event that could be lost on overflow. It is still unverified
shell code and currently dispatches to the scaffold/adapter entry points under
smoke coverage. The rich
`DNS.ShellScheduler.dispatch_shell_event` model remains in the `make extract`
smoke gate but is not part of the linked shell ABI yet, because the full worker
branch still reaches non-Low* response-construction state. Direct lower-level
calls remain available as verified boundaries, but new C shell integration
should target the `DNS.ShellBoundary` scheduler helper wrappers first.

`DNS.Security.Handshake.process_crypto_frame` and
`DNS.Security.Gateway.decrypt_and_validate` are legacy transitional adapter
entry points. They should be bypassed once MsQuic owns TLS handshake,
authentication policy, packet protection, and authenticated stream delivery.

QUIC/TLS authenticity, handshake acceptance, certificate/authentication policy,
packet protection, key updates, flow control, recovery, and connection lifecycle
are trusted through the MsQuic shell stack and adapter interfaces listed in
`docs/THREAT_MODEL.md`.

## Pulse/Rust Migration ABI

The migration lane also exercises a value-state Pulse shell-boundary pilot that
extracts to Rust. It is not a production shell ABI yet, but `make
pulse-rust-smoke` verifies the current FFI shape by:

- extracting `migration/DNS.Migration.PulseShellBoundaryValue.fst` to Rust;
- compiling an unverified Rust `staticlib` wrapper around the generated module;
- linking a tiny C caller against that wrapper.

The wrapper deliberately exposes only C-friendly value types:

- `uint32_t buffered`
- `uint32_t capacity`
- `uint32_t phase`
- `uint8_t accepted`

Phase values are:

- `0`: reading
- `1`: processing
- `2`: closed

Invalid phase values are treated as `closed` before calling the generated Rust
module. The wrapper owns no buffers and performs no DNS parsing, QUIC/TLS,
allocation, or scheduling. It only adapts the generated value-state Rust
functions to an extern-friendly shape so a future shell can call a stable
boundary without depending on generated Rust enum layout.

## Buffer Ownership

Each buffer crossing from the shell into verified code has a single writer for
the duration of the call.

- Input ciphertext and stream-fragment buffers are immutable while verified code
  is reading them.
- MsQuic stream fragments passed through
  `handle_authenticated_stream_fragment` must name the matching verified
  `stream_context.sc_id`.
- The shell must not free, reallocate, resize, or mutate a buffer until the
  verified call that received it has returned.
- Destination buffers passed to verified copy/update functions must be
  disjoint from source buffers whenever the callee requires `disjoint` or
  `loc_disjoint`.
- The shell must preserve any live `connection_context`, `stream_context`, and
  cache buffers across calls that rely on stored pointers.
- Connection contexts must set `cc_capacity` to a bound no larger than the
  allocated stream pointer table and keep `cc_num <= cc_capacity` before calling
  verified stream lookup or allocation routines.
- Connection buffers, stream pointer tables, and stream context buffers must be
  pairwise disjoint when calling verified stream close or worker routines that
  may compact the active stream table.
- Ownership transfer must be explicit at FFI boundaries. Borrowed buffers return
  to shell ownership after the call; persistent buffers remain owned by the
  connection, stream, or cache object named in the verified precondition.

## Scheduling Contract

The shell scheduler is responsible for choosing which verified function runs and
when. It must maintain the logical ownership expected by the verified model:

- Prefer `DNS.ShellBoundary.dispatch_authenticated_stream_data` for generated C
  authenticated ingress.
- Prefer `DNS.ShellBoundary.process_ready_stream_for_response` for generated C
  minimal worker error-response on streams already marked `Processing`.
- Prefer `DNS.ShellBoundary.process_ready_stream_for_empty_response` for
  generated C header-only empty NOERROR responses on streams already marked
  `Processing`.
- Prefer `DNS.ShellBoundary.process_ready_stream_for_validated_minimal_response`
  for generated C minimal worker responses that should choose between a
  question-echoing zero-answer NOERROR response and FORMERR based on the
  generated parser boundary.
- Keep `DNS.Worker.Minimal.prepare_worker_minimal_error_response_send` and
  `DNS.Worker.Minimal.prepare_worker_empty_noerror_response_send` as direct
  scaffold helpers, and keep
  `DNS.Worker.Minimal.prepare_worker_validated_minimal_response_send` as the
  current C-linked validated worker response helper until the production
  response path is rewritten into an extraction-friendly representation.
- Prefer `DNS.ShellResponseBoundary.prepare_response_send_for_stream` and
  `DNS.ShellResponseBoundary.complete_response_send_for_stream` for generated C
  response handoff and send-completion/drop cleanup.
- Prefer the `DNS.ShellBoundary.*_via_scheduler` wrappers when the C shell wants
  one scheduler-shaped ABI surface for ingress, minimal worker responses,
  and send-completion/drop cleanup.
- Keep `shell/ism_shell.c` as the fixed-capacity scaffold that owns generated C
  connection/stream buffers.
- Keep `shell/msquic_adapter.c` as the current MsQuic-shaped shell adapter; it
  routes authenticated stream bytes through scheduler helper wrappers, prepares
  ready responses through the generated-validator-backed selector, and leaves
  send completion as a separate callback.
- Keep `shell/ism_event_queue.c` as the current fixed-capacity shell event
  queue for staging authenticated-ingress, ready-response, and send-completion
  events before dispatching them to the adapter/scaffold. Derived ready
  responses from completed ingress are serviced synchronously by the dispatcher
  rather than re-enqueued.
- Keep `shell/msquic_runtime.c` as the optional real-MsQuic callback seam. The
  default build covers dependency-free receive/send-completion translation
  helpers; defining `ISM_ENABLE_MSQUIC=1` compiles the wrapper that consumes
  upstream `QUIC_STREAM_EVENT` receive and send-completion shapes.
- MsQuic receive bytes must be copied into shell-owned ingress storage before
  verified ingress sees them. The current runtime seam rejects receive fragments
  larger than that fixed-capacity storage and only queues the copied bytes.
- Delayed queueing of receive bytes must keep using shell-owned storage; the
  shell must never retain pointers into callback-owned MsQuic buffers.
- Keep `DNS.ShellScheduler.dispatch_shell_event` as the verified model-level
  dispatch point for authenticated stream data, processing-ready streams, and
  send-completion/drop notifications.
- At most one worker mutates a given `stream_context` at a time until real Steel
  permissions replace the bootstrap adapter.
- A stream marked `Processing` carries the completed DNS message length and may
  be passed to the minimal C-linked worker helper or, in verification-only
  model paths, to `DNS.Worker.worker_loop`; other stream phases should be
  accumulated through `handle_stream_data`.
- Closed or reset streams must not be reused while any verified pointer still
  aliases their buffers.
- The shell must enforce connection, stream, and buffer-count limits before
  allocation. Verified code currently models only conservative first-slot
  lookup/allocation behavior.

## Egress Contract

The preferred MsQuic egress handoff is:

- `DNS.ShellResponseBoundary.prepare_doq_response_send_for_stream`
- `DNS.ShellResponseBoundary.prepare_response_send_for_stream`
- `DNS.ShellResponseBoundary.complete_response_send_for_stream`
- `DNS.QUIC.MsQuicEgress.prepare_response_send`
- `DNS.QUIC.MsQuicSendCompletion.complete_response_send`

Response construction and QUIC writes are not fully integrated. Until the C
shell calls the egress handoff and wires it to MsQuic sends:

- the shell may drop a request after verified processing;
- the shell must pass a caller-owned Low* response buffer and explicit capacity
  to the current minimal worker helper or a future extraction-friendly
  production worker boundary;
- the shell must pass a separate caller-owned stream buffer to
  `prepare_doq_response_send_for_stream`; verified code writes the RFC 9250
  two-octet response length prefix followed by the DNS response bytes into that
  buffer;
- DoQ-framed response bytes handed to `prepare_response_send` must be treated
  as immutable until encryption/write completion, or copied into shell-owned
  send storage before verified code can mutate or free the source bytes;
- MsQuic response fragments passed through the handoff must name the matching
  verified `stream_context.sc_id`;
- stream close/cleanup must be sequenced after send completion or after the
  shell decides to drop the response by calling `complete_response_send`;
- AEAD encryption, QUIC packetization, congestion control, retransmission, and
  path validation remain trusted responsibilities of the MsQuic shell stack.

## Audit and Test Requirements

The unverified shell must stay small and auditable.

- Keep socket, scheduler, FFI, and allocation code separate from DNS policy.
- Add fuzz tests for malformed packets, fragmented streams, overlong lengths,
  stream resets, allocation failures, and concurrent close/read races.
- Run sanitizers on shell builds when using an ordinary C compiler.
- Run `make c-compile-smoke` after extraction-sensitive changes to
  syntax-check the generated C bundle and EverParse wrapper.
- Run `make c-link-smoke` after generated C boundary changes to link and run
  the current protocol/EverParse generated-wrapper strict-subset checks,
  `DNS.ShellBoundary` ingress/minimal worker response, scheduler helper
  wrappers, and `DNS.ShellResponseBoundary` response handoff/completion harness
  plus the fixed-capacity C shell scaffold and MsQuic-shaped adapter smoke
  path plus the dependency-free MsQuic runtime seam. This does not yet cover the
  rich `DNS.ShellScheduler.dispatch_shell_event` union or a real linked MsQuic
  shell path.
- Run `make MSQUIC_CFLAGS=... msquic-runtime-compile-smoke` when real MsQuic
  headers are available to syntax-check the optional `QUIC_STREAM_EVENT`
  callback wrapper.
- Run `make pulse-rust-smoke` after migration-lane Pulse/Rust boundary changes
  to compile the generated Rust, link the extern-friendly wrapper from C, and
  keep the experimental ABI shape honest.
- Keep generated EverParse wrapper symbols aligned with `make
  everparse-generate` and `make everparse-verify`.
- Update `docs/THREAT_MODEL.md` whenever the shell gains or loses trusted
  behavior, exported entry points, ownership assumptions, or adapter contracts.

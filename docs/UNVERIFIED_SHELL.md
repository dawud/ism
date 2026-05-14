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

The preferred MsQuic ingress call is:

- `DNS.ShellScheduler.dispatch_shell_event`
- `DNS.QUIC.MsQuicIngress.handle_authenticated_stream_fragment`

The shell may call verified ingress functions only when their preconditions are
established by construction or checked before the call:

- `DNS.ShellScheduler.dispatch_shell_event`
- `DNS.QUIC.StreamMapping.handle_stream_data`
- `DNS.QUIC.Multiplexer.find_stream`
- `DNS.Worker.worker_loop`

`DNS.ShellScheduler.dispatch_shell_event` and the worker path it reaches are
included in the `make extract` smoke gate. Direct lower-level calls remain
available as verified boundaries, but new shell integration should target the
dispatcher first.

`DNS.Security.Handshake.process_crypto_frame` and
`DNS.Security.Gateway.decrypt_and_validate` are legacy transitional adapter
entry points. They should be bypassed once MsQuic owns TLS handshake,
authentication policy, packet protection, and authenticated stream delivery.

QUIC/TLS authenticity, handshake acceptance, certificate/authentication policy,
packet protection, key updates, flow control, recovery, and connection lifecycle
are trusted through the MsQuic shell stack and adapter interfaces listed in
`docs/THREAT_MODEL.md`.

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

- Prefer `DNS.ShellScheduler.dispatch_shell_event` as the single verified
  dispatch point for authenticated stream data, processing-ready streams, and
  send-completion/drop notifications. This dispatcher is part of the extracted
  shell-facing surface.
- At most one worker mutates a given `stream_context` at a time until real Steel
  permissions replace the bootstrap adapter.
- A stream marked `Processing` carries the completed DNS message length and may
  be passed to `DNS.Worker.worker_loop`; other stream phases should be
  accumulated through `handle_stream_data`.
- Closed or reset streams must not be reused while any verified pointer still
  aliases their buffers.
- The shell must enforce connection, stream, and buffer-count limits before
  allocation. Verified code currently models only conservative first-slot
  lookup/allocation behavior.

## Egress Contract

The preferred MsQuic egress handoff is:

- `DNS.QUIC.MsQuicEgress.prepare_response_send`
- `DNS.QUIC.MsQuicSendCompletion.complete_response_send`

Response construction and QUIC writes are not fully integrated. Until the C
shell calls the egress handoff and wires it to MsQuic sends:

- the shell may drop a request after verified processing;
- the shell must pass a caller-owned Low* response buffer and explicit capacity
  to `DNS.Worker.worker_loop`;
- response bytes copied into that buffer and handed to `prepare_response_send`
  must be treated as immutable until encryption/write completion, or copied
  into shell-owned send storage before verified code can mutate or free the
  source bytes;
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
- Keep generated EverParse wrapper symbols aligned with `make
  everparse-generate` and `make everparse-verify`.
- Update `docs/THREAT_MODEL.md` whenever the shell gains or loses trusted
  behavior, exported entry points, ownership assumptions, or adapter contracts.

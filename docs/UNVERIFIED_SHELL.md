# Unverified Shell Boundary

This document defines the contract for the C shell that surrounds the verified
DNS-over-QUIC core. The shell is trusted code: it is allowed to perform OS,
QUIC, TLS, allocation, and scheduling work that is not yet verified, but it must
cross into the F*/Low* core only through narrow, documented entry points.

## Scope

The shell owns:

- POSIX socket setup, polling, reads, writes, and shutdown.
- QUIC packet I/O, connection dispatch, stream event delivery, and flow-control
  integration until EverQuic is wired in directly.
- Thread creation, worker scheduling, timers, signal handling, and process
  lifecycle.
- Allocation and release of host-side buffers before they are handed to Low*.
- FFI glue between generated C, EverCrypt/EverQuic/miTLS, and the OS.

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

The shell may call the current verified ingress functions only when their
preconditions are established by construction or checked before the call:

- `DNS.Security.Handshake.process_crypto_frame`
- `DNS.Security.Gateway.decrypt_and_validate`
- `DNS.QUIC.StreamMapping.handle_stream_data`
- `DNS.QUIC.Multiplexer.find_stream`
- `DNS.Worker.worker_loop`

Until real EverQuic/miTLS integration lands, QUIC/TLS authenticity and
handshake acceptance are trusted through the adapter interfaces listed in
`docs/THREAT_MODEL.md`.

## Buffer Ownership

Each buffer crossing from the shell into verified code has a single writer for
the duration of the call.

- Input ciphertext and stream-fragment buffers are immutable while verified code
  is reading them.
- The shell must not free, reallocate, resize, or mutate a buffer until the
  verified call that received it has returned.
- Destination buffers passed to verified copy/update functions must be
  disjoint from source buffers whenever the callee requires `disjoint` or
  `loc_disjoint`.
- The shell must preserve any live `connection_context`, `stream_context`, and
  cache buffers across calls that rely on stored pointers.
- Ownership transfer must be explicit at FFI boundaries. Borrowed buffers return
  to shell ownership after the call; persistent buffers remain owned by the
  connection, stream, or cache object named in the verified precondition.

## Scheduling Contract

The shell scheduler is responsible for choosing which verified function runs and
when. It must maintain the logical ownership expected by the verified model:

- At most one worker mutates a given `stream_context` at a time until real Steel
  permissions replace the bootstrap adapter.
- A stream marked `Processing` may be passed to `DNS.Worker.worker_loop`; other
  stream phases should be accumulated through `handle_stream_data`.
- Closed or reset streams must not be reused while any verified pointer still
  aliases their buffers.
- The shell must enforce connection, stream, and buffer-count limits before
  allocation. Verified code currently models only conservative first-slot
  lookup/allocation behavior.

## Egress Contract

Response construction, encryption, and QUIC writes are not fully integrated.
Until they are verified or backed by real EverQuic/miTLS contracts:

- the shell may drop a request after verified processing;
- any response bytes emitted by future verified serializers must be treated as
  immutable until encryption/write completion;
- AEAD encryption, QUIC packetization, congestion control, retransmission, and
  path validation remain trusted shell or EverQuic responsibilities.

## Audit and Test Requirements

The unverified shell must stay small and auditable.

- Keep socket, scheduler, FFI, and allocation code separate from DNS policy.
- Add fuzz tests for malformed packets, fragmented streams, overlong lengths,
  stream resets, allocation failures, and concurrent close/read races.
- Run sanitizers on shell builds when using an ordinary C compiler.
- Keep generated EverParse wrapper symbols aligned with `make
  everparse-generate` and `make everparse-verify`.
- Update `docs/THREAT_MODEL.md` whenever the shell gains or loses trusted
  behavior, exported entry points, ownership assumptions, or adapter contracts.


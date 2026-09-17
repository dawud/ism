# Verified DNS-over-QUIC Server in F*

This project aims to implement a mathematically verified DNS server using F*, Low*, and the Project Everest ecosystem (HACL*, EverCrypt, EverParse, Steel).

## Documentation

- **[Architecture](docs/ARCHITECTURE.md)**: Runtime flow, verified components, and trust boundaries.
- **[Implementation Plan](docs/PLAN.md)**: High-level strategy and RFC roadmap.
- **[Threat Model](docs/THREAT_MODEL.md)**: STRIDE analysis and Post-Quantum assessment.
- **[Development Roadmap](docs/TODO.md)**: Active task tracking and progress.
- **[Proof-audit actions](docs/PROOF_AUDIT_ACTIONS.md)**: Implemented repairs, verification evidence, and open proof gates.

## Key Features

- **Verified components:** Sequential Low* memory-safety obligations and selected functional contracts, under explicit caller assumptions.
- **DoQ prototype:** Length/FIN framing and a minimal question-echo responder, with trusted MsQuic transport and TLS.
- **DNS models:** Bounded parsing, checked serialization, authoritative lookup and cache scaffolds; not complete RFC semantics.
- **Explicit limits:** No end-to-end server correctness, race-freedom, constant-time, or local cryptographic proof. See the [trusted-boundary inventory](docs/THREAT_MODEL.md).

## Project Structure

- `src/protocol`: DNS wire format and protocol definitions.
- `src/security`: Legacy cryptographic/handshake adapters, not the runtime TLS stack.
- `src/transport`: QUIC stream mapping and framing.
- `src/logic`: Core DNS lookup logic (Authoritative & Recursive).
- `src/concurrency`: Sequential worker/cache/shell scaffolds; Steel permissions are placeholders.
- `spec`: Trusted local compatibility and external-library interfaces.
- `shell`: C adapters and executable smoke tests; F* regressions live with the sources.

## Building & Running
The project uses F* for verification and KaRaMel for extraction to C.

### Toolchain Version Policy
This repository is currently pinned to F* `v2026.03.24`, the last project
baseline before the removal of the old Low* sublanguage in F* `v2026.04.17`.
Newer F* releases, including the weekly `v2026.05.03` line, should be tracked
in a separate migration lane until the Low*/Pulse/KaRaMeL strategy is settled.

Routine development should use the pinned container image. Upgrading the main
toolchain past `v2026.03.24` is a migration task, not a routine dependency
refresh.

Stable KaRaMeL is pinned to `11bb8e1ac2f720fb7144b9b768c7251526caa149`.
Base-image and transitive package inputs are not fully locked, so this is not
a claim of fully reproducible builds.

The repository also includes a non-blocking migration container in
`Containerfile.migration`. That image tracks a recent F* release for compatibility
testing only; failures there are migration evidence and do not replace the pinned
development lane.

### Using Podman/Docker (Recommended)
The development toolchain is provided by the local container image
`localhost/verified-dns-server:latest`. Mount this repository at `/workspace`;
the image's default command runs `make verify`.

```bash
# Run formal verification with the prebuilt local image
podman run --rm \
  --userns=keep-id \
  -v "$(pwd):/workspace:Z" \
  localhost/verified-dns-server:latest
```

If the local image is missing, build it from the checked-in `Containerfile`:

```bash
podman build -t localhost/verified-dns-server:latest -f Containerfile .
```

To test the current sources against a recent F* release without changing the
stable toolchain, build and run the migration image:

```bash
podman build \
  --build-arg FSTAR_VERSION=v2026.05.10 \
  -t localhost/verified-dns-server:fstar-migration \
  -f Containerfile.migration .

podman run --rm \
  --userns=keep-id \
  -v "$(pwd):/workspace:Z" \
  localhost/verified-dns-server:fstar-migration
```

The migration image's default command verifies only the Pulse pilot. To also
capture the current Rust-extraction assessment and legacy F*/Low*
incompatibilities, run:

```bash
podman run --rm \
  --userns=keep-id \
  -v "$(pwd):/workspace:Z" \
  localhost/verified-dns-server:fstar-migration \
  bash -lc 'make verify-pulse-pilot && make pulse-rust-smoke && make verify'
```

To compile and run the generated Rust smoke check for the value-state Pulse
pilot, run:

```bash
podman run --rm \
  --userns=keep-id \
  -v "$(pwd):/workspace:Z" \
  localhost/verified-dns-server:fstar-migration \
  bash -lc 'make pulse-rust-smoke'
```

To run a specific build target, override the default command:

```bash
podman run --rm \
  --userns=keep-id \
  -v "$(pwd):/workspace:Z" \
  localhost/verified-dns-server:latest \
  bash -lc 'eval $(opam env) && make extract'
```

To syntax-check the generated C bundle and EverParse wrapper without linking a
final shell binary, run:

```bash
podman run --rm \
  --userns=keep-id \
  -v "$(pwd):/workspace:Z" \
  localhost/verified-dns-server:latest \
  bash -lc 'make c-compile-smoke'
```

To link and run the current generated parser and shell-boundary smoke binary,
including ingress, response handoff, and the fixed-capacity C shell scaffold,
run:

```bash
podman run --rm \
  --userns=keep-id \
  -v "$(pwd):/workspace:Z" \
  localhost/verified-dns-server:latest \
  bash -lc 'make c-link-smoke'
```

To syntax-check the wrappers that consume real MsQuic stream, connection, and
listener callback types, use the pinned MsQuic header installed in the
container:

```bash
podman run --rm \
  --userns=keep-id \
  -v "$(pwd):/workspace:Z" \
  localhost/verified-dns-server:latest \
  bash -lc 'make msquic-runtime-compile-smoke'
```

To link and run the no-network MsQuic connection callback behavior smoke check,
using a fake MsQuic API table and the pinned upstream callback types, run:

```bash
podman run --rm \
  --userns=keep-id \
  -v "$(pwd):/workspace:Z" \
  localhost/verified-dns-server:latest \
  bash -lc 'make msquic-runtime-connection-smoke'
```

To link and run the no-network MsQuic runtime smoke check, use the pinned
MsQuic headers and shared library installed in the container:

```bash
podman run --rm \
  --userns=keep-id \
  -v "$(pwd):/workspace:Z" \
  localhost/verified-dns-server:latest \
  bash -lc 'make msquic-runtime-link-smoke'
```

To check the no-network MsQuic object lifecycle boundary, including API table,
registration, configuration, and listener handle ownership, run:

```bash
podman run --rm \
  --userns=keep-id \
  -v "$(pwd):/workspace:Z" \
  localhost/verified-dns-server:latest \
  bash -lc 'make msquic-runtime-lifecycle-smoke'
```

To start and stop a real loopback MsQuic listener on an ephemeral local port,
without accepting connections or sending traffic, run:

```bash
podman run --rm \
  --userns=keep-id \
  -v "$(pwd):/workspace:Z" \
  localhost/verified-dns-server:latest \
  bash -lc 'make msquic-runtime-listener-smoke'
```

To run a live loopback MsQuic stream exchange through the current stream
receive and send callback boundaries, using test-only loopback credentials
under `shell/`, run:

```bash
podman run --rm \
  --userns=keep-id \
  -v "$(pwd):/workspace:Z" \
  localhost/verified-dns-server:latest \
  bash -lc 'make msquic-runtime-stream-smoke'
```

The gate sends a valid DoQ query from the client, submits the generated response
through the real MsQuic `StreamSend` API, and checks the exact response bytes at
the client before accepting server-side send completion.

For a non-container MsQuic installation, override `MSQUIC_CFLAGS` and
`MSQUIC_LDFLAGS` with the needed include and link flags.

The image also includes EverParse/3D tooling. To regenerate the current
EverParse parser scaffold and verify/extract the generated subset, run:

```bash
podman run --rm \
  --userns=keep-id \
  -v "$(pwd):/workspace:Z" \
  localhost/verified-dns-server:latest \
  bash -lc 'make everparse-verify'
```

With Docker, run the container as your host UID/GID so generated `obj/`,
`dist/`, or `generated/` files are writable on the bind mount. Omit the SELinux
`:Z` suffix if your Docker setup does not support it:

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -v "$(pwd):/workspace" \
  localhost/verified-dns-server:latest \
  bash -lc 'make verify'
```

### Manual Build
See the [Makefile](Makefile) for details. Requires F* v2026.03.24 and KaRaMel.

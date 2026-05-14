# Verified DNS-over-QUIC Server in F*

This project aims to implement a mathematically verified DNS server using F*, Low*, and the Project Everest ecosystem (HACL*, EverCrypt, EverParse, Steel).

## Documentation
- **[Architecture](docs/ARCHITECTURE.md)**: Layered security design and Mermaid diagrams.
- **[Implementation Plan](docs/PLAN.md)**: High-level strategy and RFC roadmap.
- **[Threat Model](docs/THREAT_MODEL.md)**: STRIDE analysis and Post-Quantum assessment.
- **[Development Roadmap](docs/TODO.md)**: Active task tracking and progress.

## Key Features
- **Formal Verification:** Memory safety and functional correctness proven in F*.
- **DNS-over-QUIC (DoQ):** Implementation based on RFC 9250.
- **Modern Standards:** Support for TLS 1.3 and modern DNS resource records.
- **Security First:** Parser-rejecting architecture and verified cryptographic primitives.

## Project Structure
- `src/protocol`: DNS wire format and protocol definitions.
- `src/security`: Cryptographic integration and TLS 1.3 handshake.
- `src/transport`: QUIC stream mapping and framing.
- `src/logic`: Core DNS lookup logic (Authoritative & Recursive).
- `src/concurrency`: Steel-based concurrent memory management.
- `spec`: High-level RFC specifications.
- `tests`: Unit tests and fuzzing harness.

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

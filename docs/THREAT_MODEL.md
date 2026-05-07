# Threat Model: Verified DNS-over-QUIC Server

This document outlines the threat landscape, security boundaries, and mitigation strategies for the verified DNS server.

## 1. STRIDE Analysis

| Threat Category | Potential Attack Vector | Mitigation Strategy (Verified Solution) |
| :--- | :--- | :--- |
| **Spoofing** | DNS Cache Poisoning; Client Impersonation. | Bailiwick checks in F* core; TLS 1.3 certificate-based identity. |
| **Tampering** | Packet modification in transit. | EverCrypt AEAD (AES-GCM/ChachaPoly) ensuring data integrity. |
| **Repudiation** | Denying a query was sent/responded to. | QUIC Packet Numbers and verified logging (Steel-protected). |
| **Information Disclosure** | Side-channel timing attacks; Packet sniffing. | Constant-time crypto (HACL*); DoQ encryption; Query Padding (EDNS0). |
| **Denial of Service** | QUIC stream exhaustion; Memory bloating. | Steel-enforced resource bounds; QUIC flow control; Fuzzed I/O shell. |
| **Elevation of Privilege** | Exploit in parser to get shell access. | EverParse guaranteed memory safety; Parser-rejecting logic. |

---

## 2. The Verification Boundary: Shell vs. Core

A critical part of our threat model is acknowledging the **Trusted Computing Base (TCB)**.

- **The Core (Verified):** Mathematically proven to be free of buffer overflows, use-after-free errors, and data races.
- **The Shell (Unverified):** The C code it extracts to, the compiler that translates it, and the OS kernel handling the sockets.

### Residual Risks at the Boundary
- **Kernel Vulnerabilities:** An exploit in the Linux/BSD UDP stack handling the QUIC packets could bypass our verified server entirely.
- **Memory Corruption in FFI:** The small "bridge" code that moves data from C buffers into Low* pointers is a high-priority target for an auditor.
- **Compiler Mis-optimization:** While CompCert mitigates this, using standard `gcc` or `clang` introduces the risk that the compiler might optimize away a security check that it deems "redundant."

### Trusted Boundary Inventory
This inventory must be kept current as proof debt is removed. A passing F* verification run proves the obligations currently written, but it does not automatically discharge these trusted boundaries.

| Boundary | Current Status | Risk | Required Closure |
| :--- | :--- | :--- | :--- |
| Local `spec/*.fsti` interfaces | Local Project Everest / Low* / Steel compatibility interfaces exist in the repository and are documented as trusted bootstrap adapters. | Verification may prove against weaker local contracts than the real libraries provide. | Replace each adapter with the corresponding real dependency as integration work lands. |
| EverCrypt AEAD bootstrap adapter | `spec/EverCrypt.AEAD.fsti` is an import-stability shim with no exported cryptographic operations; the active AEAD model is the local `DNS.Security.Gateway.decrypt` boundary. | AEAD authenticity is not supplied by a real EverCrypt contract. | Replace the shim and gateway model with the real EverCrypt AEAD interface, including nonce, key, tag, plaintext, and authenticity contracts. |
| EverCrypt cipher/helper bootstrap adapters | `spec/EverCrypt.Cipher.fsti`, `spec/EverCrypt.Helpers.fsti`, and `spec/Spec.Agile.Cipher.fsti` are import-stability shims with no exported cipher, helper, or agile-algorithm contracts. | TLS handshake and crypto-context proofs do not inherit real EverCrypt, miTLS, or agile-cipher guarantees. | Replace the shims with real Project Everest interfaces and connect supported ciphers, key material, and client-hello validation to those contracts. |
| LowParse bootstrap adapter | `spec/LowParse.Low.Base.fsti` documents a trusted adapter for `uint8_ptr` and the unused placeholder `parser` type. The parser boundary now has a production-target subset entry point, but external EverParse/LowParse generation is not wired in yet. | Parser proofs rely on a local LowParse surface until the real EverParse/LowParse dependency is wired in. | Replace with the real LowParse interface when integrating the generated EverParse parser. |
| Steel bootstrap adapter | `spec/Steel.Memory.fsti` maps `pointer` to LowStar buffers and erases `vprop` to `unit`; `spec/Steel.ST.Util.fsti` is an import-stability shim. | Concurrency proofs do not yet establish real Steel permissions or invariants. | Replace with real Steel interfaces and prove shard/cache/worker permissions. |
| AEAD decrypt | `DNS.Security.Gateway.decrypt` currently returns `Success`; `decrypt_and_validate` copies the bounded ciphertext range into a concrete Low* plaintext workspace before parsing. | Authenticated plaintext is assumed, so tampering protection is not established by the current code. | Integrate EverCrypt AEAD or expose a narrow trusted decrypt interface with a stated authenticity theorem. |
| TLS client hello validation | `verify_client_hello` currently accepts all inputs. | Client authentication and protocol negotiation are not enforced. | Replace with miTLS/EverQuic integration or a documented trusted handshake adapter. |
| DNS parser completeness | Header, question, buffer, and flag round-trip parser obligations are admitted-free; RR sections are parsed structurally with bounded RDATA preservation, unknown TYPE values are preserved as `UNKNOWN`, truncated RR headers/RDATA are rejected, invalid A/AAAA RDATA lengths are rejected, NS/CNAME/PTR RDATA must be a single uncompressed name, and EDNS0 OPT pseudo-RRs/options are accepted only in version-0 additional-section form with bounded option data. | Parser-rejecting claims currently cover structural RR parsing, A/AAAA length checks, name-bearing RDATA shape checks, and structural OPT/EDNS option checks, not broader type-specific RDATA semantics, response-side EDNS serialization, or compression-pointer support. | Implement remaining type-specific RDATA validation, response-side EDNS serialization, and compression support or keep each unsupported behavior explicitly rejected, then extend parser-rejecting proofs and shared parser tests. |
| QNAME compression | Compression pointers are rejected, not implemented. | This is safe but incomplete for RFC 1035 compatibility. | Either document permanent rejection or implement pointer parsing with loop prevention and bounds proofs. |
| QUIC stream handling | The two-byte DoQ length prefix parser reads from a bounded Low* buffer, stream phase updates are persisted in the stream context, one-byte split length prefixes are stored until completion, complete length-prefix fragments account for following body bytes, bounded body bytes are copied into the stream buffer, `ReadingMessage` advances to `Processing` once enough bytes arrive, overlong body fragments transition to `Done`, `find_stream` performs a conservative first-slot lookup, `allocate_stream` is an explicit no-allocation placeholder, and `close_stream` is an explicit no-op placeholder; real allocation and close/removal semantics are still incomplete. | Resource exhaustion and stream confusion defenses are partially modeled, but full stream lifecycle bounds are not yet proven. | Implement allocation, close/removal, and resource-bound proofs. |
| Steel cache permissions | `shard_permission` is assumed. | Race-freedom for the shared cache is not established. | Replace assumed permissions with Steel invariants and proofs. |
| Recursive cache operations | Cache lookup and insertion are admitted. | TTL enforcement and cache isolation are only partially modeled. | Implement lookup/add/eviction with memory and TTL proofs. |
| Bailiwick suffix check | `is_subdomain` is currently mocked for most non-shorter child names. | Cache poisoning defenses are not established. | Implement and prove DNS-name suffix matching. |
| Unverified shell | Socket I/O, event loop, and thread scheduling are not implemented. | Bugs outside the verified core may corrupt buffers or violate assumptions. | Keep shell small, document ownership transfer, fuzz it, and audit the FFI boundary. |
| Extraction and compiler | Verification is checked; extraction is not yet a routine gate. | Verified code may not yet correspond to a buildable C artifact. | Run KaRaMeL extraction regularly and eventually compile with the chosen C compiler/CompCert path. |
| F* release migration | Mainline uses F* `v2026.03.24`; F* `v2026.04.17` removed old Low*. | Upgrading blindly may invalidate Low*/KaRaMeL assumptions or strand executable code. | Keep a stable pinned lane and a non-blocking latest-F* migration lane until the Pulse/KaRaMeL/EverParse strategy is proven. |
| Hardware and microarchitecture | Outside formal model. | Side channels such as Spectre/Meltdown remain possible. | Document deployment assumptions and use constant-time primitives for cryptographic operations. |

---

## 3. Specific DoQ & Recursive Logic Threats

### A. The "Amplification" Threat
DNS is historically used for DDoS amplification. Since we use QUIC, we are protected by **Address Validation**.
- **Threat:** An attacker spoofs a source IP to trigger a large DNS response.
- **Mitigation:** The QUIC stack (via EverQuic) refuses to send a response larger than the received request until the path is validated (the 3-Way Handshake).

### B. CNAME Loop Exhaustion
- **Threat:** A zone file or recursive response contains a CNAME loop (`a.com -> b.com -> a.com`).
- **Mitigation:** The Verified Radix Tree logic includes a "Fuel" or "Hop Count" metric. F* proves the function terminates after N hops, returning `ServFail`.

### C. Cache Side-Channels
- **Threat:** An attacker measures the latency of a response to see if a domain is already in our recursive cache.
- **Mitigation:** We implement Artificial Jitter or Bucketized Timing in the Steel-based cache. Because our code is constant-time, we can ensure that every cache lookup (hit or miss) falls within a predictable timing window.

---

## 4. Post-Quantum Threat Model

### A. "Harvest Now, Decrypt Later" (HNDL)
- **Threat:** State actors record encrypted DNS traffic today to decrypt it using a future quantum computer.
- **Mitigation:** **Hybrid KEM**. By binding ML-KEM with X25519, we ensure that session data remains protected by the lattice-based secret even if the classical secret is broken.

### B. Quantum Forgery
- **Threat:** An attacker uses a quantum computer to derive the private key of a Root CA or a DNSSEC Root Zone KSK.
- **Mitigation:** Transitioning to **ML-DSA (Dilithium)** signatures for identity and using **DoQ** to handle the larger signature payloads that exceed traditional UDP limits.

### C. The "PQC Tax" (Resource Exhaustion)
- **Threat:** PQC algorithms are computationally "heavy" and produce large payloads (e.g., ML-DSA-65 signatures are ~3.3 KB). This increases the risk of CPU-exhaustion DoS.
- **Mitigation:** Steel-enforced resource limits and pre-allocation of workspace memory for PQC operations to prevent heap fragmentation.

---

## 5. Security Summary of the Architecture

The resulting server is a **Hardened Fortress**. By moving the security boundary from "reactive patching" to "proactive proof," the attack surface is reduced to:
1.  **Hardware/CPU:** (Spectre/Meltdown type attacks).
2.  **OS Kernel:** (Network stack).
3.  **Formal Specifications:** (i.e., did we accurately model the RFC rules?).

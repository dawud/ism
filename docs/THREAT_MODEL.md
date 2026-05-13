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
- **The Shell (Unverified):** The C code it extracts to, the compiler that translates it, and the OS kernel handling the sockets. The shell/core contract is documented in [UNVERIFIED_SHELL.md](UNVERIFIED_SHELL.md).

### Residual Risks at the Boundary
- **Kernel Vulnerabilities:** An exploit in the Linux/BSD UDP stack handling the QUIC packets could bypass our verified server entirely.
- **Memory Corruption in FFI:** The small "bridge" code that moves data from C buffers into Low* pointers is a high-priority target for an auditor.
- **Compiler Mis-optimization:** While CompCert mitigates this, using standard `gcc` or `clang` introduces the risk that the compiler might optimize away a security check that it deems "redundant."

### Trusted Boundary Inventory
This inventory must be kept current as proof debt is removed. A passing F* verification run proves the obligations currently written, but it does not automatically discharge these trusted boundaries.

| Boundary | Current Status | Risk | Required Closure |
| :--- | :--- | :--- | :--- |
| Local `spec/*.fsti` interfaces | Local Project Everest / Low* / Steel compatibility interfaces and the generated EverParse C-wrapper F* interface exist in the repository and are documented as trusted bootstrap adapters. | Verification may prove against weaker local contracts than the real libraries provide, or against a narrower generated-wrapper contract than the C build actually links. | Replace each adapter with the corresponding real dependency as integration work lands, and keep generated C-wrapper symbols tied to `make everparse-generate`/`make everparse-verify`. |
| EverCrypt AEAD bootstrap adapter | `spec/EverCrypt.AEAD.fsti` exports the trusted `decrypt_authenticated` success/failure boundary used by `DNS.Security.Gateway.decrypt`. | AEAD authenticity is not supplied by a real EverCrypt contract. | Replace the shim and gateway model with the real EverCrypt AEAD interface, including nonce, key, tag, plaintext, and authenticity contracts. |
| EverCrypt cipher/helper bootstrap adapters | `spec/EverCrypt.Cipher.fsti` exports the trusted `validate_client_hello` success/failure boundary used by `DNS.Security.Handshake.verify_client_hello`; `spec/EverCrypt.Helpers.fsti` and `spec/Spec.Agile.Cipher.fsti` remain import-stability shims with no exported helper or agile-algorithm contracts. | TLS handshake and crypto-context proofs do not inherit real EverCrypt, miTLS, or agile-cipher guarantees. | Replace the shims with real Project Everest interfaces and connect supported ciphers, key material, and client-hello validation to those contracts. |
| LowParse/EverParse generated boundary | The local LowParse shim has been removed. The parser boundary now has a production-target subset entry point, a checked-in 3D grammar seed for bounded uncompressed-QNAME question validation, a single-answer RR packet subset, A/AAAA fixed-RDLENGTH answer subsets, NS/CNAME/PTR name-RDATA answer subsets, an MX preference/exchange-name answer subset, an SOA two-name/timer answer subset, an SRV priority/weight/port/target-name answer subset, and a TXT character-string answer subset, opt-in generation and verification targets, containerized EverParse/3D tooling, CI generation of the subset artifact, an EverParse-verified adapter that imports the generated validator symbols, and an active Low* buffer gate through the generated C wrapper for question-only packets with bounded uncompressed QNAMEs plus one-question/one-answer packets with bounded uncompressed names, raw bounded RDATA, generated A/AAAA length checks, generated name-RDATA shape checks, generated MX shape checks, generated SOA shape checks, generated SRV shape checks, and generated TXT shape checks. Full packet construction still uses the handwritten reference parser. | Parser proofs still rely on a hand-authored generated-boundary shim outside the generated subset, and the F* interface for the generated C wrapper is trusted. | Expand the grammar across the remaining RR-section forms and type-specific RDATA shapes, replace reference construction or prove equivalence, and keep the generated C-wrapper interface aligned with generated artifacts. |
| Steel bootstrap adapter | `spec/Steel.Memory.fsti` maps `pointer` to LowStar buffers and erases `vprop` to `unit`; `spec/Steel.ST.Util.fsti` is an import-stability shim. | Concurrency proofs do not yet establish real Steel permissions or invariants. | Replace with real Steel interfaces and prove shard/cache/worker permissions. |
| AEAD decrypt | `DNS.Security.Gateway.decrypt` branches on the trusted `EverCrypt.AEAD.decrypt_authenticated` adapter result; `decrypt_and_validate` copies the bounded ciphertext range into a concrete Low* plaintext workspace before parsing only after success. | Authenticated plaintext is still trusted through the adapter, so tampering protection is not established by a real crypto proof in the current code. | Integrate EverCrypt AEAD or replace the adapter with a stated authenticity theorem backed by the real implementation. |
| TLS client hello validation | `verify_client_hello` branches on the trusted `EverCrypt.Cipher.validate_client_hello` adapter result. | Client authentication and protocol negotiation are still trusted through the adapter rather than established by real TLS proof or implementation. | Replace with miTLS/EverQuic integration or a stated handshake theorem backed by the real implementation. |
| DNS parser completeness | Header, question, buffer, and flag round-trip parser obligations are admitted-free; RR sections are parsed structurally with bounded RDATA preservation, the generated boundary gates question-only packets, the first single-answer RR subset, A/AAAA fixed-RDLENGTH answer subsets, NS/CNAME/PTR uncompressed name-RDATA answer subsets, MX uncompressed preference/exchange-name answer subsets, SOA two-name/timer answer subsets, SRV uncompressed priority/weight/port/target-name answer subsets, and TXT character-string answer subsets, unknown TYPE values are preserved as `UNKNOWN`, truncated RR headers/RDATA are rejected, invalid A/AAAA RDATA lengths are rejected, compressed RR owner names, NS/CNAME/PTR RDATA names, MX exchange names, SOA mname/rname names, and SRV target names may point to prior message offsets, SOA RDATA must contain two fully-consumed names plus five 32-bit timer fields, TXT RDATA must contain one or more fully-consumed character strings, EDNS0 OPT pseudo-RRs/options are accepted only in version-0 additional-section form with bounded option data, and basic response/EDNS0 option/padding packet serialization validates section counts and round-trips question-only packets through the parser. | Parser-rejecting claims currently cover structural RR parsing, generated A/AAAA length checks, generated NS/CNAME/PTR uncompressed name-RDATA shape checks, generated MX uncompressed shape checks, generated SOA shape checks, generated SRV uncompressed shape checks, generated TXT shape checks, malformed RR owner/RDATA-name compression pointers, structural OPT/EDNS option checks, and basic response/OPT/Padding packet serialization, not broader type-specific RDATA semantics or full response-side EDNS policy integration. | Implement remaining type-specific RDATA validation and response-side EDNS policy integration, or keep each unsupported behavior explicitly rejected, then extend parser-rejecting proofs and shared parser tests. |
| QNAME compression | RR owner-name, NS/CNAME/PTR RDATA-name, MX exchange-name, SOA mname/rname, and SRV target-name compression pointers to prior message offsets are accepted with fuel-bounded recursion; question-name, self-loop, forward, and out-of-range pointers are rejected. | Partial support improves RFC 1035 compatibility while retaining bounded pointer validation. | Keep loop-prevention/bounds tests in place and document any newly unsupported compression context explicitly. |
| QUIC stream handling | The two-byte DoQ length prefix parser reads from a bounded Low* buffer, stream phase updates are persisted in the stream context, one-byte split length prefixes are stored until completion, complete length-prefix fragments account for following body bytes, bounded body bytes are copied into the stream buffer, `ReadingMessage` advances to `Processing` once enough bytes arrive, overlong body fragments transition to `Done`, `find_stream` performs a bounded active-slot scan, `worker_loop` performs a conservative first-slot lookup, the worker consumes matching `Processing` streams by moving them to `Done` and invoking `close_stream`, `allocate_stream` initializes the next active slot when connection capacity remains, and `close_stream` conservatively removes a matching first active stream by setting the active count to zero; real response generation, polling, and multi-slot close semantics are still incomplete. | Resource exhaustion and stream confusion defenses are partially modeled, but full stream lifecycle bounds and response-processing behavior are not yet proven. | Implement response generation, polling, multi-slot close, and resource-bound proofs. |
| Steel cache permissions | `shard_permission` is a concrete erased `vprop` placeholder through the trusted Steel bootstrap adapter, and sharded cache get/add conservatively use the first shard with explicit live-buffer preconditions. | Race-freedom for the shared cache is not established because real Steel invariants and hash-based shard ownership are still absent. | Replace erased placeholder permissions with Steel invariants and proofs. |
| Recursive cache operations | Cache lookup and insertion no longer use local admits; lookup checks a conservative first slot for name and TTL validity, and insertion writes a saturated-expiry entry to the first slot when capacity is nonzero. | Full bounded scanning, replacement/eviction, negative caching, and sharded concurrency integration are incomplete. | Implement full lookup/add/eviction with memory, TTL, and concurrency proofs. |
| Bailiwick suffix check | `is_subdomain` now performs DNS-name suffix matching over label lists, and `validate_answer` rejects answer owner names outside the authority zone. | Broader recursive answer validation is still incomplete. | Extend recursive validation around referrals, ranking, and cache insertion policy. |
| CNAME chasing | `chase_cname` now inspects CNAME records, decodes one fully-consumed uncompressed target name from RDATA, follows targets with a hop bound, returns `ServFail` on malformed targets or hop exhaustion, and returns `NXDomain` when a followed target is absent. | Full CNAME/RRset semantics, ranking, and response construction are incomplete. | Extend CNAME handling to full RFC semantics and connect it to response generation and cache policy. |
| Zone parser | `parse_zone_file` no longer returns a fixed `None`; it routes bytes through a bootstrap parser for one binary zone-entry shape with origin QNAME, TTL, CLASS, TYPE, RDLENGTH, and exact RDATA bytes, with A/AAAA length checks. | Full RFC master-file text parsing, multi-entry iteration, and broader type-specific RDATA validation are incomplete. | Extend the parser to master-file syntax or document the accepted zone format, add multi-entry loading, and keep RDATA validation aligned with authoritative lookup behavior. |
| Wildcard lookup | In-memory radix lookup now falls back to a literal `*` child when the queried label is absent, while exact children take precedence. | Full RFC 4592 closest-encloser and response-synthesis semantics are not modeled yet. | Extend wildcard lookup to the full RFC model and connect it to zone loading and response generation. |
| Unverified shell | [UNVERIFIED_SHELL.md](UNVERIFIED_SHELL.md) documents socket/QUIC I/O responsibilities, allowed calls into verified modules, buffer ownership transfer, scheduler assumptions, egress responsibilities, and audit/fuzzing requirements. Socket I/O, real event-loop integration, and production scheduling are not implemented yet. | Bugs outside the verified core may corrupt buffers, violate aliasing assumptions, or call verified entry points without satisfying their preconditions. | Keep shell small, implement only the documented boundary, fuzz malformed I/O and scheduling edges, and audit the FFI boundary. |
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

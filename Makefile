# Paths to your F* and KaRaMel installations
FSTAR_HOME  ?= /opt/fstar/fstar
KRML_HOME   ?= /opt/karamel
INCLUDE_DIR = $(FSTAR_HOME)/ulib/.cache

# Project Directories
SRC_DIRS    = src/protocol src/security src/transport src/logic src/concurrency spec
MIGRATION_DIR = migration
OBJ_DIR     = obj
DIST_DIR    = dist
GENERATED_DIR = generated
EVERPARSE_SRC_DIR = everparse
EVERPARSE_OUT_DIR = $(GENERATED_DIR)/everparse
EVERPARSE_CMD ?= everparse.sh
EVERPARSE_HOME ?= /opt/everparse
PULSE_HOME ?= $(FSTAR_HOME)/lib/fstar/pulse
PULSE_KRML ?= $(FSTAR_HOME)/bin/krml
EVERPARSE_INCLUDE_DIRS = $(EVERPARSE_OUT_DIR) \
                         $(EVERPARSE_HOME)/src/3d/prelude/buffer \
                         $(EVERPARSE_HOME)/src/3d/prelude \
                         $(EVERPARSE_HOME)/src/lowparse \
                         $(EVERPARSE_HOME)/krmllib \
                         $(EVERPARSE_HOME)/krmllib/obj
PULSE_INCLUDE_DIRS = $(MIGRATION_DIR) \
                     $(PULSE_HOME)/common \
                     $(PULSE_HOME)/common.checked \
                     $(PULSE_HOME)/pulse \
                     $(PULSE_HOME)/pulse.checked \
                     $(PULSE_HOME)/pulse/lib \
                     $(PULSE_HOME)/pulse/lib/class

# F* configuration
FSTAR_OPTS  = --odir $(OBJ_DIR) --cache_dir $(OBJ_DIR) \
              $(addprefix --include , $(SRC_DIRS))

PULSE_PILOT_OBJ_DIR = $(OBJ_DIR)/pulse-pilot
PULSE_PILOT_RUST_DIR = $(DIST_DIR)/pulse-rust
PULSE_REF_PILOT_FST_FILE = $(MIGRATION_DIR)/DNS.Migration.PulseShellBoundary.fst
PULSE_VALUE_PILOT_FST_FILE = $(MIGRATION_DIR)/DNS.Migration.PulseShellBoundaryValue.fst
PULSE_PILOT_FST_FILES = $(PULSE_REF_PILOT_FST_FILE) $(PULSE_VALUE_PILOT_FST_FILE)
PULSE_REF_PILOT_KRML_FILE = $(PULSE_PILOT_RUST_DIR)/DNS_Migration_PulseShellBoundary.krml
PULSE_VALUE_PILOT_KRML_FILE = $(PULSE_PILOT_RUST_DIR)/DNS_Migration_PulseShellBoundaryValue.krml
PULSE_REF_PILOT_RUST_LOG = $(PULSE_PILOT_RUST_DIR)/rust-ref-translation.log
PULSE_VALUE_PILOT_RUST_LOG = $(PULSE_PILOT_RUST_DIR)/rust-value-translation.log
PULSE_VALUE_PILOT_RUST_FILE = $(PULSE_PILOT_RUST_DIR)/dns/migration_pulseshellboundaryvalue.rs
PULSE_RUST_SMOKE_FILE = $(PULSE_PILOT_RUST_DIR)/pulse_value_smoke.rs
PULSE_RUST_SMOKE_BIN = $(PULSE_PILOT_RUST_DIR)/pulse-value-smoke
PULSE_RUST_FFI_SOURCE = $(MIGRATION_DIR)/rust/pulse_value_ffi.rs
PULSE_RUST_FFI_LIB = $(PULSE_PILOT_RUST_DIR)/libpulse_value_ffi.a
PULSE_RUST_FFI_SMOKE_C_SOURCE = $(MIGRATION_DIR)/rust/pulse_value_ffi_smoke.c
PULSE_RUST_FFI_SMOKE_BIN = $(PULSE_PILOT_RUST_DIR)/pulse-value-ffi-smoke
RUSTC ?= rustc
PULSE_PILOT_FSTAR_OPTS = --odir $(PULSE_PILOT_OBJ_DIR) \
                         --cache_dir $(PULSE_PILOT_OBJ_DIR) \
                         $(addprefix --include , $(PULSE_INCLUDE_DIRS))
PULSE_PILOT_KRML_EXTRACT_OPTS = -fsopt --no_cmi \
                                -verify \
                                -backend rust \
                                -skip-translation \
                                -tmpdir $(PULSE_PILOT_RUST_DIR) \
                                $(addprefix -I , $(PULSE_INCLUDE_DIRS))
PULSE_PILOT_RUST_TRANSLATE_OPTS = -backend rust \
                                  -drop C \
                                  -skip-compilation \
                                  -tmpdir $(PULSE_PILOT_RUST_DIR)

EVERPARSE_FSTAR_OPTS = --odir $(EVERPARSE_OUT_DIR) --cache_dir $(EVERPARSE_OUT_DIR) \
                       $(addprefix --include , $(EVERPARSE_INCLUDE_DIRS)) \
                       --already_cached 'Prims,LowStar,FStar,LowParse,C,EverParse3d.*,Spec'

# KaRaMel configuration
KRML_OPTS   = -drop 'FStar.Tactics.*' -drop 'FStar.Reflection.*' \
              -bundle DNS.Protocol=DNS.Protocol,DNS.Name,DNS.Constants,DNS.RCode,DNS.Protocol.* \
              -bundle DNS.ShellBoundary=DNS.Security.*,DNS.QUIC.*,DNS.Zone.RadixTree,DNS.Worker,DNS.ShellScheduler,DNS.ShellBoundary \
              -bundle DNS.ShellResponseBoundary=DNS.ShellResponseBoundary \
              -add-include '"krml/internal/compat.h"' \
              -tmpdir $(DIST_DIR) -skip-compilation

# C syntax smoke gate for generated artifacts. This deliberately stops short of
# linking a runnable shell; it checks that the current extracted C surface and
# EverParse wrapper are consumable by a C compiler.
CC ?= cc
C_SMOKE_CFLAGS = -std=c11 -D_DEFAULT_SOURCE -D_BSD_SOURCE \
                 -I $(DIST_DIR) \
                 -I $(DIST_DIR)/internal \
                 -I $(EVERPARSE_OUT_DIR) \
                 -I $(EVERPARSE_HOME)/krmllib/dist/minimal \
                 -I $(EVERPARSE_HOME)/src/3d/prelude \
                 -I $(EVERPARSE_HOME)/src/3d/prelude/buffer
C_COMPILE_SMOKE_CFLAGS = $(C_SMOKE_CFLAGS) -fsyntax-only
C_COMPILE_SMOKE_SOURCES = $(DIST_DIR)/DNS_Protocol.c \
                          $(wildcard $(DIST_DIR)/DNS_ShellBoundary.c) \
                          $(wildcard $(DIST_DIR)/DNS_ShellResponseBoundary.c) \
                          $(EVERPARSE_OUT_DIR)/DNSProtocol.c \
                          $(EVERPARSE_OUT_DIR)/DNSProtocolWrapper.c
C_LINK_SMOKE = $(DIST_DIR)/c-link-smoke
C_LINK_SMOKE_SOURCES = shell/link_smoke.c \
                       shell/link_protocol_smoke.c \
                       shell/link_everparse_smoke.c \
                       shell/link_shell_boundary_smoke.c \
                       shell/link_shell_response_boundary_smoke.c \
                       shell/link_shell_scaffold_smoke.c \
                       shell/ism_shell.c \
                       shell/link_krml_compat_stubs.c \
                       $(C_COMPILE_SMOKE_SOURCES)

# 1. Collect all F* source files
PROTOCOL_FST_FILES = src/protocol/DNS.Name.fst \
                     src/protocol/DNS.Protocol.fst \
                     src/protocol/DNS.Constants.fst \
                     src/protocol/DNS.RCode.fst \
                     src/protocol/DNS.Protocol.OPT.fst \
                     src/protocol/DNS.Protocol.Parser.fst \
                     src/protocol/DNS.Protocol.Parser.EverParseGenerated.fst \
                     src/protocol/DNS.Protocol.Parser.EverParseBoundary.fst \
                     src/protocol/DNS.Protocol.Serializer.fst \
                     src/protocol/DNS.Protocol.Parser.Tests.fst

ALL_FST_FILES = $(PROTOCOL_FST_FILES) \
                $(wildcard src/security/*.fst) \
                $(wildcard src/transport/*.fst) \
                $(wildcard src/logic/*.fst) \
                $(wildcard src/concurrency/*.fst) \
                $(wildcard spec/*.fsti)

# Extraction is narrower than verification while most Phase 3/4 scaffolds still
# contain specification-oriented lists and Steel placeholders. It includes the
# shell-facing worker/dispatcher boundary so the unverified shell can target an
# extracted API while cache and broader concurrency proofs remain verification-only.
EXTRACT_FST_FILES = $(filter-out src/protocol/%.Tests.fst, $(PROTOCOL_FST_FILES)) \
                    $(wildcard src/security/*.fst) \
                    $(wildcard src/transport/*.fst) \
                    src/logic/DNS.Zone.RadixTree.fst \
                    src/concurrency/DNS.Worker.fst \
                    src/concurrency/DNS.ShellScheduler.fst \
                    src/concurrency/DNS.ShellBoundary.fst \
                    src/concurrency/DNS.ShellResponseBoundary.fst \
                    $(wildcard spec/*.fsti)

EVERPARSE_3D_FILES = $(wildcard $(EVERPARSE_SRC_DIR)/*.3d)

.PHONY: all verify verify-pulse-pilot assess-pulse-pilot-rust pulse-rust-smoke extract c-compile-smoke c-link-smoke everparse-generate everparse-verify clean

all: extract

# 2. Verification Stage
# We verify each file individually to ensure we see the specific errors.
# We no longer rely on complex .depend for this bootstrap phase.
verify:
	@mkdir -p $(OBJ_DIR)
	@echo "Verifying Source Files..."
	$(FSTAR_HOME)/bin/fstar.exe $(FSTAR_OPTS) $(ALL_FST_FILES)

verify-pulse-pilot:
	@mkdir -p $(PULSE_PILOT_OBJ_DIR)
	@echo "Verifying Pulse migration pilot..."
	@for f in $(PULSE_PILOT_FST_FILES); do \
		$(FSTAR_HOME)/bin/fstar.exe $(PULSE_PILOT_FSTAR_OPTS) $$f || exit $$?; \
	done

assess-pulse-pilot-rust:
	@mkdir -p $(PULSE_PILOT_RUST_DIR)
	@echo "Extracting Pulse ref-based pilot to KaRaMeL for Rust assessment..."
	$(PULSE_KRML) $(PULSE_PILOT_KRML_EXTRACT_OPTS) $(PULSE_REF_PILOT_FST_FILE)
	@test -s $(PULSE_REF_PILOT_KRML_FILE)
	@echo "Attempting Pulse ref-based pilot Rust translation..."
	@set +e; \
	$(PULSE_KRML) $(PULSE_PILOT_RUST_TRANSLATE_OPTS) $(PULSE_REF_PILOT_KRML_FILE) >$(PULSE_REF_PILOT_RUST_LOG) 2>&1; \
	status=$$?; \
	if grep -q "ERROR translating" $(PULSE_REF_PILOT_RUST_LOG); then \
		cat $(PULSE_REF_PILOT_RUST_LOG); \
		exit 1; \
	elif [ $$status -eq 0 ]; then \
		echo "Pulse ref-based pilot Rust translation succeeded."; \
	else \
		if grep -q "Pulse.Lib.Reference.op_Bang has no corresponding implementation" $(PULSE_REF_PILOT_RUST_LOG); then \
			echo "Pulse ref-based pilot Rust translation is blocked by missing Pulse.Lib.Reference runtime support; see $(PULSE_REF_PILOT_RUST_LOG)."; \
		else \
			cat $(PULSE_REF_PILOT_RUST_LOG); \
			exit $$status; \
		fi; \
	fi
	@echo "Extracting Pulse value-state pilot to KaRaMeL for Rust assessment..."
	$(PULSE_KRML) $(PULSE_PILOT_KRML_EXTRACT_OPTS) $(PULSE_VALUE_PILOT_FST_FILE)
	@test -s $(PULSE_VALUE_PILOT_KRML_FILE)
	@echo "Attempting Pulse value-state pilot Rust translation..."
	@set +e; \
	$(PULSE_KRML) $(PULSE_PILOT_RUST_TRANSLATE_OPTS) $(PULSE_VALUE_PILOT_KRML_FILE) >$(PULSE_VALUE_PILOT_RUST_LOG) 2>&1; \
	status=$$?; \
	if grep -q "ERROR translating" $(PULSE_VALUE_PILOT_RUST_LOG); then \
		cat $(PULSE_VALUE_PILOT_RUST_LOG); \
		exit 1; \
	elif [ $$status -ne 0 ]; then \
		cat $(PULSE_VALUE_PILOT_RUST_LOG); \
		exit $$status; \
	fi
	@echo "Pulse value-state pilot Rust translation succeeded; see $(PULSE_PILOT_RUST_DIR)."

pulse-rust-smoke: assess-pulse-pilot-rust
	@test -s $(PULSE_VALUE_PILOT_RUST_FILE)
	@command -v $(RUSTC) >/dev/null 2>&1 || { \
		echo "Rust compiler '$(RUSTC)' was not found."; \
		echo "Install rustc or use Containerfile.migration."; \
		exit 127; \
	}
	@printf '%s\n' \
	  '#[path = "dns/migration_pulseshellboundaryvalue.rs"]' \
	  'mod migration_pulseshellboundaryvalue;' \
	  '' \
	  'use migration_pulseshellboundaryvalue as pilot;' \
	  '' \
	  'fn main() {' \
	  '    let initial = pilot::stream_state {' \
	  '        buffered: 4,' \
	  '        capacity: 12,' \
	  '        phase: pilot::shell_phase::ValueReading,' \
	  '    };' \
	  '    assert!(pilot::uu___is_ValueReading(initial.phase));' \
	  '    assert_eq!(pilot::available(initial), 8);' \
	  '    assert!(pilot::accepts_fragment(initial, 8));' \
	  '    let accepted = pilot::dispatch_authenticated_bytes_value(initial, 8);' \
	  '    assert!(accepted.accepted);' \
	  '    assert_eq!(accepted.next.buffered, 12);' \
	  '    assert!(matches!(accepted.next.phase, pilot::shell_phase::ValueProcessing));' \
	  '    assert!(pilot::uu___is_ValueProcessing(accepted.next.phase));' \
	  '    let rejected = pilot::dispatch_authenticated_bytes_value(accepted.next, 1);' \
	  '    assert!(!rejected.accepted);' \
	  '    assert!(matches!(rejected.next.phase, pilot::shell_phase::ValueClosed));' \
	  '    assert!(pilot::uu___is_ValueClosed(rejected.next.phase));' \
	  '}' \
	  > $(PULSE_RUST_SMOKE_FILE)
	$(RUSTC) --edition=2021 $(PULSE_RUST_SMOKE_FILE) -o $(PULSE_RUST_SMOKE_BIN)
	$(PULSE_RUST_SMOKE_BIN)
	@echo "Pulse value-state generated Rust compiled and ran successfully."
	$(RUSTC) --edition=2021 --crate-type staticlib $(PULSE_RUST_FFI_SOURCE) -o $(PULSE_RUST_FFI_LIB)
	$(CC) -std=c11 $(PULSE_RUST_FFI_SMOKE_C_SOURCE) $(PULSE_RUST_FFI_LIB) -lpthread -ldl -lm -o $(PULSE_RUST_FFI_SMOKE_BIN)
	$(PULSE_RUST_FFI_SMOKE_BIN)
	@echo "Pulse value-state Rust FFI wrapper compiled, linked, and ran successfully."

# 3. Extraction Stage
extract: everparse-verify verify
	@echo "Extracting to C in $(DIST_DIR)..."
	mkdir -p $(DIST_DIR)
	$(KRML_HOME)/krml $(KRML_OPTS) $(EXTRACT_FST_FILES)

c-compile-smoke: extract
	@echo "Syntax-checking generated C artifacts..."
	KRML_INCLUDEDIR="$$($(KRML_HOME)/krml -locate-include)"; \
	KRML_LIBDIR="$$($(KRML_HOME)/krml -locate-krmllib)"; \
	$(CC) $(C_COMPILE_SMOKE_CFLAGS) \
	  -I "$$KRML_INCLUDEDIR" \
	  -I "$$KRML_LIBDIR/dist/minimal" \
	  $(C_COMPILE_SMOKE_SOURCES)

c-link-smoke: extract
	@echo "Linking generated C boundary smoke binary..."
	KRML_INCLUDEDIR="$$($(KRML_HOME)/krml -locate-include)"; \
	KRML_LIBDIR="$$($(KRML_HOME)/krml -locate-krmllib)"; \
	$(CC) $(C_SMOKE_CFLAGS) \
	  -I "$$KRML_INCLUDEDIR" \
	  -I "$$KRML_LIBDIR/dist/minimal" \
	  $(C_LINK_SMOKE_SOURCES) \
	  -o $(C_LINK_SMOKE); \
	$(C_LINK_SMOKE)

# 4. EverParse generation scaffold
everparse-generate:
	@mkdir -p $(EVERPARSE_OUT_DIR)
	@command -v $(EVERPARSE_CMD) >/dev/null 2>&1 || { \
		echo "EverParse command '$(EVERPARSE_CMD)' was not found."; \
		echo "Set EVERPARSE_CMD to everparse.sh or bin/3d.exe from an EverParse release."; \
		exit 127; \
	}
	$(EVERPARSE_CMD) --odir $(EVERPARSE_OUT_DIR) --no_clang_format $(EVERPARSE_3D_FILES)

everparse-verify: everparse-generate
	@test -s $(EVERPARSE_OUT_DIR)/DNSProtocol.fst
	@test -s $(EVERPARSE_OUT_DIR)/DNSProtocol.fsti
	@test -s $(EVERPARSE_OUT_DIR)/DNSProtocol.c
	@test -s $(EVERPARSE_OUT_DIR)/DNSProtocol.h
	@test -s $(EVERPARSE_OUT_DIR)/DNSProtocolWrapper.c
	@test -s $(EVERPARSE_OUT_DIR)/DNSProtocolWrapper.h
	$(EVERPARSE_HOME)/bin/fstar.exe $(EVERPARSE_FSTAR_OPTS) src/protocol/DNS.Protocol.Parser.EverParseAdapter.fst
	@echo "EverParse DNSProtocol subset generated and verified."

# 4. Cleanup
clean:
	rm -rf $(OBJ_DIR) $(DIST_DIR) $(GENERATED_DIR) .depend

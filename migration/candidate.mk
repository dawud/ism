include migration/toolchain.lock

CANDIDATE_LANE = candidate-$(FSTAR_VERSION)
CANDIDATE_OBJ_DIR = obj/$(CANDIDATE_LANE)
CANDIDATE_DIST_DIR = dist/$(CANDIDATE_LANE)
CANDIDATE_C_DIR = $(CANDIDATE_DIST_DIR)/pulse-c
CANDIDATE_STREAM_C_DIR = $(CANDIDATE_DIST_DIR)/pulse-stream
CANDIDATE_STREAM_ARCHIVE = $(CANDIDATE_STREAM_C_DIR)/libism_pulse_stream.a
CANDIDATE_STREAM_CFLAGS = -std=c11 -O2 -D_DEFAULT_SOURCE -D_BSD_SOURCE \
                         -Wall -Wextra -Werror -I migration/c -I $(CANDIDATE_STREAM_C_DIR) \
                         -I $(FSTAR_HOME)/include/krml -I $(FSTAR_HOME)/lib/krml/dist/minimal
CANDIDATE_Z3 = $(FSTAR_HOME)/lib/fstar/z3-$(Z3_VERSION)/bin/z3
CANDIDATE_FSTAR_OPTS = --z3version $(Z3_VERSION) --smt $(CANDIDATE_Z3) \
                      --cache_checked_modules

.PHONY: candidate-check candidate-toolchain-check candidate-verify candidate-extract \
        candidate-c-smoke migration-inventory-check candidate-stream-verify \
        candidate-stream-extract candidate-stream-library candidate-stream-c-smoke

CANDIDATE_STREAM_FILES = src/transport/DNS.QUIC.StreamModel.fst \
                         src/transport/DNS.QUIC.StreamModel.Tests.fst \
                         migration/DNS.Migration.PulseStream.fst \
                         migration/DNS.Migration.PulseStream.Tests.fst

CANDIDATE_MULTIPLEXER_FILES = src/transport/DNS.QUIC.TableModel.fst \
                              src/transport/DNS.QUIC.TableModel.Tests.fst \
                              migration/DNS.Migration.PulseMultiplexer.fst \
                              migration/DNS.Migration.PulseMultiplexer.Tests.fst
CANDIDATE_MULTIPLEXER_C_DIR = $(CANDIDATE_DIST_DIR)/pulse-multiplexer
CANDIDATE_MULTIPLEXER_MODULES = DNS.QUIC.StreamModel DNS.QUIC.TableModel DNS.Migration.PulseStream DNS.Migration.PulseMultiplexer Pulse.Lib.Pervasives

.PHONY: candidate-multiplexer-verify candidate-multiplexer-extract candidate-multiplexer-c-smoke
candidate-multiplexer-verify: candidate-stream-verify
	@mkdir -p $(CANDIDATE_OBJ_DIR)/multiplexer
	@for f in $(CANDIDATE_MULTIPLEXER_FILES); do \
	  $(FSTAR_HOME)/bin/fstar.exe $(CANDIDATE_FSTAR_OPTS) \
	    --odir $(CANDIDATE_OBJ_DIR)/multiplexer --cache_dir $(CANDIDATE_OBJ_DIR)/multiplexer \
	    --include $(CANDIDATE_OBJ_DIR)/stream --include src/transport \
	    $(addprefix --include ,$(PULSE_INCLUDE_DIRS)) $$f || exit $$?; \
	done

candidate-multiplexer-extract: candidate-multiplexer-verify
	@mkdir -p $(CANDIDATE_MULTIPLEXER_C_DIR)
	$(FSTAR_HOME)/bin/fstar.exe $(CANDIDATE_FSTAR_OPTS) --warn_error +250 \
	  --cache_dir $(CANDIDATE_OBJ_DIR)/multiplexer --odir $(CANDIDATE_MULTIPLEXER_C_DIR) \
	  --include $(CANDIDATE_OBJ_DIR)/stream --include src/transport \
	  $(addprefix --include ,$(PULSE_INCLUDE_DIRS)) \
	  --codegen krml --extract '$(CANDIDATE_MULTIPLEXER_MODULES)' migration/DNS.Migration.PulseMultiplexer.fst
	$(FSTAR_HOME)/bin/krml -tmpdir $(CANDIDATE_MULTIPLEXER_C_DIR) -skip-compilation \
	  -warn-error @2@4@15 \
	  -bundle 'DNS.Migration.PulseMultiplexer=DNS.QUIC.StreamModel,DNS.QUIC.TableModel,DNS.Migration.PulseStream,DNS.Migration.PulseMultiplexer,Pulse.Lib.Pervasives' \
	  $(CANDIDATE_MULTIPLEXER_C_DIR)/out.krml
	@test -s $(CANDIDATE_MULTIPLEXER_C_DIR)/DNS_Migration_PulseMultiplexer.c
	@test -s $(CANDIDATE_MULTIPLEXER_C_DIR)/DNS_Migration_PulseMultiplexer.h

# Standalone M4 table contract tests, not yet a mixed-shell table replacement.
candidate-multiplexer-c-smoke: candidate-multiplexer-extract
	$(CC) $(CANDIDATE_STREAM_CFLAGS) -I $(CANDIDATE_MULTIPLEXER_C_DIR) \
	  $(CANDIDATE_MULTIPLEXER_C_DIR)/DNS_Migration_PulseMultiplexer.c \
	  migration/c/pulse_multiplexer_smoke.c -o $(CANDIDATE_MULTIPLEXER_C_DIR)/pulse-multiplexer-smoke
	$(CANDIDATE_MULTIPLEXER_C_DIR)/pulse-multiplexer-smoke

candidate-stream-verify: candidate-toolchain-check
	@mkdir -p $(CANDIDATE_OBJ_DIR)/stream
	@for f in $(CANDIDATE_STREAM_FILES); do \
	  $(FSTAR_HOME)/bin/fstar.exe $(CANDIDATE_FSTAR_OPTS) \
	    --odir $(CANDIDATE_OBJ_DIR)/stream --cache_dir $(CANDIDATE_OBJ_DIR)/stream \
	    --include src/transport $(addprefix --include ,$(PULSE_INCLUDE_DIRS)) \
	    $$f || exit $$?; \
	done

candidate-toolchain-check:
	@mkdir -p $(CANDIDATE_DIST_DIR)
	python3 migration/check_toolchain.py --fstar-home $(FSTAR_HOME) --cc '$(CC)' \
	  > $(CANDIDATE_DIST_DIR)/toolchain.json.tmp
	@mv $(CANDIDATE_DIST_DIR)/toolchain.json.tmp $(CANDIDATE_DIST_DIR)/toolchain.json
	@cat $(CANDIDATE_DIST_DIR)/toolchain.json

migration-inventory-check:
	@mkdir -p $(CANDIDATE_DIST_DIR)
	python3 migration/check_inventory.py --verified $(ALL_FST_FILES) \
	  --extracted $(EXTRACT_FST_FILES) \
	  --candidate $(PULSE_PILOT_FST_FILES) $(CANDIDATE_STREAM_FILES) $(CANDIDATE_MULTIPLEXER_FILES) \
	  --candidate-extracted $(PULSE_VALUE_PILOT_FST_FILE) \
	    src/transport/DNS.QUIC.StreamModel.fst migration/DNS.Migration.PulseStream.fst \
	    src/transport/DNS.QUIC.TableModel.fst migration/DNS.Migration.PulseMultiplexer.fst \
	  > $(CANDIDATE_DIST_DIR)/inventory.json.tmp
	@mv $(CANDIDATE_DIST_DIR)/inventory.json.tmp $(CANDIDATE_DIST_DIR)/inventory.json
	@echo "Migration inventory checked; see $(CANDIDATE_DIST_DIR)/inventory.json"

candidate-verify: candidate-toolchain-check candidate-stream-verify candidate-multiplexer-verify
	$(MAKE) verify-pulse-pilot BUILD_LANE=$(CANDIDATE_LANE) \
	  PULSE_PILOT_FSTAR_OPTS='--odir $(CANDIDATE_OBJ_DIR)/pulse-pilot \
	    --cache_dir $(CANDIDATE_OBJ_DIR)/pulse-pilot $(CANDIDATE_FSTAR_OPTS) \
	    $(addprefix --include ,$(PULSE_INCLUDE_DIRS))'

# Retain the original M1 value-only pilot independently of the real stream gate.
candidate-extract: candidate-verify
	@mkdir -p $(CANDIDATE_C_DIR)/checked
	$(FSTAR_HOME)/bin/krml -fstar $(FSTAR_HOME)/bin/fstar.exe \
	  -fsopt --no_cmi $(foreach opt,$(CANDIDATE_FSTAR_OPTS),-fsopt $(opt)) \
	  -fsopt --cache_dir -fsopt $(CANDIDATE_C_DIR)/checked \
	  $(addprefix -I ,$(PULSE_INCLUDE_DIRS)) \
	  -tmpdir $(CANDIDATE_C_DIR) -skip-translation \
	  $(PULSE_VALUE_PILOT_FST_FILE)
	$(FSTAR_HOME)/bin/krml -tmpdir $(CANDIDATE_C_DIR) -skip-compilation \
	  $(CANDIDATE_C_DIR)/DNS_Migration_PulseShellBoundaryValue.krml
	@test -s $(CANDIDATE_C_DIR)/DNS_Migration_PulseShellBoundaryValue.c
	@test -s $(CANDIDATE_C_DIR)/DNS_Migration_PulseShellBoundaryValue.h

candidate-c-smoke: candidate-extract
	$(CC) -std=c11 -D_DEFAULT_SOURCE -D_BSD_SOURCE -Wall -Wextra -Werror \
	  -I $(CANDIDATE_C_DIR) \
	  -I "$$($(FSTAR_HOME)/bin/krml -locate-include)" \
	  -I "$$($(FSTAR_HOME)/bin/krml -locate-krmllib)/dist/minimal" \
	  $(CANDIDATE_C_DIR)/DNS_Migration_PulseShellBoundaryValue.c \
	  migration/c/pulse_value_smoke.c -o $(CANDIDATE_C_DIR)/pulse-value-smoke
	$(CANDIDATE_C_DIR)/pulse-value-smoke

# Cross-module inlining is required for Pulse's reference/array primitives.
# Pervasives contributes the bundled _zero_for_deref extraction helper; do not
# replace missing primitives with hand-written/assumed runtime implementations.
# Use the checked extraction pass directly, without KaRaMeL's default --lax.
candidate-stream-extract: candidate-stream-verify
	@mkdir -p $(CANDIDATE_STREAM_C_DIR)
	$(FSTAR_HOME)/bin/fstar.exe $(CANDIDATE_FSTAR_OPTS) --warn_error +250 \
	  --cache_dir $(CANDIDATE_OBJ_DIR)/stream --odir $(CANDIDATE_STREAM_C_DIR) \
	  --include src/transport $(addprefix --include ,$(PULSE_INCLUDE_DIRS)) \
	  --codegen krml --extract 'DNS.QUIC.StreamModel DNS.Migration.PulseStream Pulse.Lib.Pervasives' \
	  migration/DNS.Migration.PulseStream.fst
	$(FSTAR_HOME)/bin/krml -tmpdir $(CANDIDATE_STREAM_C_DIR) -skip-compilation \
	  -warn-error @2@4@15 \
	  -bundle 'DNS.Migration.PulseStream=DNS.QUIC.StreamModel,DNS.Migration.PulseStream,Pulse.Lib.Pervasives' \
	  $(CANDIDATE_STREAM_C_DIR)/out.krml
	@test -s $(CANDIDATE_STREAM_C_DIR)/DNS_Migration_PulseStream.c
	@test -s $(CANDIDATE_STREAM_C_DIR)/DNS_Migration_PulseStream.h

candidate-stream-library: candidate-stream-extract
	$(CC) $(CANDIDATE_STREAM_CFLAGS) -c $(CANDIDATE_STREAM_C_DIR)/DNS_Migration_PulseStream.c \
	  -o $(CANDIDATE_STREAM_C_DIR)/DNS_Migration_PulseStream.o
	$(CC) $(CANDIDATE_STREAM_CFLAGS) -c migration/c/ism_pulse_stream.c \
	  -o $(CANDIDATE_STREAM_C_DIR)/ism_pulse_stream.o
	$(AR) rcs $(CANDIDATE_STREAM_ARCHIVE) \
	  $(CANDIDATE_STREAM_C_DIR)/DNS_Migration_PulseStream.o $(CANDIDATE_STREAM_C_DIR)/ism_pulse_stream.o

candidate-stream-c-smoke: candidate-stream-library
	$(CC) $(CANDIDATE_STREAM_CFLAGS) migration/c/pulse_stream_smoke.c \
	  $(CANDIDATE_STREAM_ARCHIVE) -o $(CANDIDATE_STREAM_C_DIR)/pulse-stream-smoke
	$(CANDIDATE_STREAM_C_DIR)/pulse-stream-smoke
	python3 migration/check_stream_artifacts.py record --directory $(CANDIDATE_STREAM_C_DIR) --cc '$(CC)'

candidate-check: migration-inventory-check candidate-c-smoke candidate-stream-c-smoke candidate-multiplexer-c-smoke

# Run with the STABLE image after candidate-check has produced the archive.
# Only C objects and the neutral ABI cross this boundary. A manifest rejects
# stale sources/objects, wrong pins, foreign C targets or missing runtime pieces.
PULSE_INTEGRATION_DIR = dist/pulse-integration-$(FSTAR_VERSION)
PULSE_INTEGRATION_OBJ_DIR = obj/pulse-integration-$(FSTAR_VERSION)
PULSE_SHELL_FLAGS = -DISM_USE_PULSE_STREAM=1 -I migration/c
PULSE_SHELL_OBJECTS = $(PULSE_INTEGRATION_OBJ_DIR)/pulse_stream_adapter.o $(CANDIDATE_STREAM_ARCHIVE)

.PHONY: pulse-stream-artifacts-check pulse-integration-check
pulse-stream-artifacts-check:
	python3 migration/check_stream_artifacts.py check --directory $(CANDIDATE_STREAM_C_DIR) --cc '$(CC)'

pulse-integration-check: extract pulse-stream-artifacts-check
	@mkdir -p $(PULSE_INTEGRATION_DIR) $(PULSE_INTEGRATION_OBJ_DIR)
	KRML_INCLUDEDIR="$$($(KRML_HOME)/krml -locate-include)"; \
	KRML_LIBDIR="$$($(KRML_HOME)/krml -locate-krmllib)"; \
	$(CC) $(C_SMOKE_CFLAGS) $(PULSE_SHELL_FLAGS) -O2 -Wall -Wextra -Werror \
	  -I "$$KRML_INCLUDEDIR" -I "$$KRML_LIBDIR/dist/minimal" \
	  -c shell/pulse_stream_adapter.c -o $(PULSE_INTEGRATION_OBJ_DIR)/pulse_stream_adapter.o && \
	$(CC) $(C_SMOKE_CFLAGS) $(PULSE_SHELL_FLAGS) -O2 -Wall -Wextra -Werror \
	  -I "$$KRML_INCLUDEDIR" -I "$$KRML_LIBDIR/dist/minimal" \
	  -c shell/ism_shell.c -o $(PULSE_INTEGRATION_OBJ_DIR)/ism_shell.o
	python3 migration/check_stream_artifacts.py selection --object $(PULSE_INTEGRATION_OBJ_DIR)/ism_shell.o
	KRML_INCLUDEDIR="$$($(KRML_HOME)/krml -locate-include)"; \
	KRML_LIBDIR="$$($(KRML_HOME)/krml -locate-krmllib)"; \
	$(CC) $(C_SMOKE_CFLAGS) -I migration/c -I shell \
	  -I "$$KRML_INCLUDEDIR" -I "$$KRML_LIBDIR/dist/minimal" \
	  migration/c/pulse_stream_differential.c shell/link_krml_compat_stubs.c \
	  shell/link_everparse_smoke.c \
	  $(C_COMPILE_SMOKE_SOURCES) $(PULSE_SHELL_OBJECTS) \
	  -o $(PULSE_INTEGRATION_DIR)/stream-differential && \
	$(PULSE_INTEGRATION_DIR)/stream-differential
	$(MAKE) -o extract c-compile-smoke c-link-smoke \
	  msquic-runtime-compile-smoke msquic-runtime-link-smoke \
	  msquic-runtime-lifecycle-smoke msquic-runtime-listener-smoke \
	  msquic-runtime-connection-smoke msquic-runtime-stream-smoke \
	  SMOKE_DIR=$(PULSE_INTEGRATION_DIR) \
	  SHELL_IMPL_SOURCE=$(PULSE_INTEGRATION_OBJ_DIR)/ism_shell.o \
	  SHELL_INGRESS_CFLAGS='$(PULSE_SHELL_FLAGS)' \
	  SHELL_INGRESS_OBJECTS='$(PULSE_SHELL_OBJECTS)'

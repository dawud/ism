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

CANDIDATE_RESPONSE_FILES = src/transport/DNS.QUIC.ResponseModel.fst \
                           src/transport/DNS.QUIC.ResponseModel.Tests.fst \
                           migration/DNS.Migration.PulseResponse.fst \
                           migration/DNS.Migration.PulseResponse.Tests.fst

CANDIDATE_RESPONSE_C_DIR = $(CANDIDATE_DIST_DIR)/pulse-response
CANDIDATE_RESPONSE_ARCHIVE = $(CANDIDATE_RESPONSE_C_DIR)/libism_pulse_response.a
CANDIDATE_RESPONSE_MODULES = DNS.QUIC.StreamModel DNS.QUIC.ResponseModel DNS.Migration.PulseStream DNS.Migration.PulseResponse Pulse.Lib.Pervasives

# Descriptor/lifetime API is proof-only; its abstract interface must be backed
# by a checked implementation before checking clients. No send C archive yet.
CANDIDATE_SEND_FILES = migration/DNS.Migration.PulseSend.fsti \
                       migration/DNS.Migration.PulseSend.fst \
                       migration/DNS.Migration.PulseSend.Tests.fst
.PHONY: candidate-send-verify
candidate-send-verify: candidate-multiplexer-verify candidate-response-verify
	@mkdir -p $(CANDIDATE_OBJ_DIR)/send
	@for f in $(CANDIDATE_SEND_FILES); do \
	  $(FSTAR_HOME)/bin/fstar.exe $(CANDIDATE_FSTAR_OPTS) \
	    --odir $(CANDIDATE_OBJ_DIR)/send --cache_dir $(CANDIDATE_OBJ_DIR)/send \
	    --include $(CANDIDATE_OBJ_DIR)/multiplexer --include $(CANDIDATE_OBJ_DIR)/response \
	    --include $(CANDIDATE_OBJ_DIR)/stream --include src/transport \
	    $(addprefix --include ,$(PULSE_INCLUDE_DIRS)) $$f || exit $$?; \
	done

.PHONY: candidate-response-verify
candidate-response-verify: candidate-stream-verify
	@mkdir -p $(CANDIDATE_OBJ_DIR)/response
	@for f in $(CANDIDATE_RESPONSE_FILES); do \
	  $(FSTAR_HOME)/bin/fstar.exe $(CANDIDATE_FSTAR_OPTS) \
	    --odir $(CANDIDATE_OBJ_DIR)/response --cache_dir $(CANDIDATE_OBJ_DIR)/response \
	    --include $(CANDIDATE_OBJ_DIR)/stream --include src/transport \
	    $(addprefix --include ,$(PULSE_INCLUDE_DIRS)) $$f || exit $$?; \
	done

.PHONY: candidate-response-extract candidate-response-library candidate-response-c-smoke
candidate-response-extract: candidate-response-verify
	@mkdir -p $(CANDIDATE_RESPONSE_C_DIR)
	$(FSTAR_HOME)/bin/fstar.exe $(CANDIDATE_FSTAR_OPTS) --warn_error +250 \
	  --cache_dir $(CANDIDATE_OBJ_DIR)/response --odir $(CANDIDATE_RESPONSE_C_DIR) \
	  --include $(CANDIDATE_OBJ_DIR)/stream --include src/transport \
	  $(addprefix --include ,$(PULSE_INCLUDE_DIRS)) \
	  --codegen krml --extract '$(CANDIDATE_RESPONSE_MODULES)' migration/DNS.Migration.PulseResponse.fst
	$(FSTAR_HOME)/bin/krml -tmpdir $(CANDIDATE_RESPONSE_C_DIR) -skip-compilation \
	  -warn-error @2@4@15 \
	  -bundle 'DNS.Migration.PulseResponse=DNS.QUIC.StreamModel,DNS.QUIC.ResponseModel,DNS.Migration.PulseStream,DNS.Migration.PulseResponse,Pulse.Lib.Pervasives' \
	  $(CANDIDATE_RESPONSE_C_DIR)/out.krml
	@test -s $(CANDIDATE_RESPONSE_C_DIR)/DNS_Migration_PulseResponse.c
	@test -s $(CANDIDATE_RESPONSE_C_DIR)/DNS_Migration_PulseResponse.h

candidate-response-library: candidate-response-extract
	$(CC) $(CANDIDATE_STREAM_CFLAGS) -I $(CANDIDATE_RESPONSE_C_DIR) \
	  -c $(CANDIDATE_RESPONSE_C_DIR)/DNS_Migration_PulseResponse.c \
	  -o $(CANDIDATE_RESPONSE_C_DIR)/DNS_Migration_PulseResponse.o
	$(CC) $(CANDIDATE_STREAM_CFLAGS) -I $(CANDIDATE_RESPONSE_C_DIR) \
	  -c migration/c/ism_pulse_response.c -o $(CANDIDATE_RESPONSE_C_DIR)/ism_pulse_response.o
	$(AR) rcs $(CANDIDATE_RESPONSE_ARCHIVE) \
	  $(CANDIDATE_RESPONSE_C_DIR)/DNS_Migration_PulseResponse.o $(CANDIDATE_RESPONSE_C_DIR)/ism_pulse_response.o

candidate-response-c-smoke: candidate-response-library
	$(CC) $(CANDIDATE_STREAM_CFLAGS) -I $(CANDIDATE_RESPONSE_C_DIR) \
	  migration/c/pulse_response_smoke.c $(CANDIDATE_RESPONSE_ARCHIVE) \
	  -o $(CANDIDATE_RESPONSE_C_DIR)/pulse-response-smoke
	$(CANDIDATE_RESPONSE_C_DIR)/pulse-response-smoke
	python3 migration/check_response_artifacts.py record --directory $(CANDIDATE_RESPONSE_C_DIR) --cc '$(CC)'

CANDIDATE_MULTIPLEXER_FILES = src/transport/DNS.QUIC.TableModel.fst \
                              src/transport/DNS.QUIC.TableModel.Tests.fst \
                              migration/DNS.Migration.PulseMultiplexer.fst \
                              migration/DNS.Migration.PulseMultiplexer.Tests.fst
CANDIDATE_MULTIPLEXER_C_DIR = $(CANDIDATE_DIST_DIR)/pulse-multiplexer
CANDIDATE_TABLE_ARCHIVE = $(CANDIDATE_MULTIPLEXER_C_DIR)/libism_pulse_table.a
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

.PHONY: candidate-table-library
candidate-table-library: candidate-multiplexer-extract
	$(CC) $(CANDIDATE_STREAM_CFLAGS) -I $(CANDIDATE_MULTIPLEXER_C_DIR) \
	  -c $(CANDIDATE_MULTIPLEXER_C_DIR)/DNS_Migration_PulseMultiplexer.c \
	  -o $(CANDIDATE_MULTIPLEXER_C_DIR)/DNS_Migration_PulseMultiplexer.o
	$(CC) $(CANDIDATE_STREAM_CFLAGS) -I $(CANDIDATE_MULTIPLEXER_C_DIR) \
	  -c migration/c/ism_pulse_table.c -o $(CANDIDATE_MULTIPLEXER_C_DIR)/ism_pulse_table.o
	$(AR) rcs $(CANDIDATE_TABLE_ARCHIVE) \
	  $(CANDIDATE_MULTIPLEXER_C_DIR)/DNS_Migration_PulseMultiplexer.o $(CANDIDATE_MULTIPLEXER_C_DIR)/ism_pulse_table.o

# Direct generated API plus neutral ABI; runtime selection is checked separately.
candidate-multiplexer-c-smoke: candidate-table-library
	$(CC) $(CANDIDATE_STREAM_CFLAGS) -I $(CANDIDATE_MULTIPLEXER_C_DIR) \
	  $(CANDIDATE_MULTIPLEXER_C_DIR)/DNS_Migration_PulseMultiplexer.c \
	  migration/c/pulse_multiplexer_smoke.c -o $(CANDIDATE_MULTIPLEXER_C_DIR)/pulse-multiplexer-smoke
	$(CANDIDATE_MULTIPLEXER_C_DIR)/pulse-multiplexer-smoke
	$(CC) $(CANDIDATE_STREAM_CFLAGS) migration/c/pulse_table_abi_smoke.c \
	  $(CANDIDATE_TABLE_ARCHIVE) -o $(CANDIDATE_MULTIPLEXER_C_DIR)/pulse-table-abi-smoke
	$(CANDIDATE_MULTIPLEXER_C_DIR)/pulse-table-abi-smoke
	python3 migration/check_table_artifacts.py record --directory $(CANDIDATE_MULTIPLEXER_C_DIR) --cc '$(CC)'

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
	  --candidate $(PULSE_PILOT_FST_FILES) $(CANDIDATE_STREAM_FILES) $(CANDIDATE_MULTIPLEXER_FILES) $(CANDIDATE_RESPONSE_FILES) $(CANDIDATE_SEND_FILES) \
	  --candidate-extracted $(PULSE_VALUE_PILOT_FST_FILE) \
	    src/transport/DNS.QUIC.StreamModel.fst migration/DNS.Migration.PulseStream.fst \
	    src/transport/DNS.QUIC.TableModel.fst migration/DNS.Migration.PulseMultiplexer.fst \
	    src/transport/DNS.QUIC.ResponseModel.fst migration/DNS.Migration.PulseResponse.fst \
	  > $(CANDIDATE_DIST_DIR)/inventory.json.tmp
	@mv $(CANDIDATE_DIST_DIR)/inventory.json.tmp $(CANDIDATE_DIST_DIR)/inventory.json
	@echo "Migration inventory checked; see $(CANDIDATE_DIST_DIR)/inventory.json"

candidate-verify: candidate-toolchain-check candidate-stream-verify candidate-multiplexer-verify candidate-response-verify candidate-send-verify
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

candidate-check: migration-inventory-check candidate-c-smoke candidate-stream-c-smoke candidate-multiplexer-c-smoke candidate-response-c-smoke

# Run with the STABLE image after candidate-check has produced the archive.
# Only C objects and the neutral ABI cross this boundary. A manifest rejects
# stale sources/objects, wrong pins, foreign C targets or missing runtime pieces.
PULSE_TABLE_ENABLED ?= 0
PULSE_RESPONSE_ENABLED ?= 0
PULSE_INTEGRATION_KIND = $(if $(filter 1,$(PULSE_RESPONSE_ENABLED)),-response,$(if $(filter 1,$(PULSE_TABLE_ENABLED)),-table))
PULSE_INTEGRATION_DIR = dist/pulse$(PULSE_INTEGRATION_KIND)-integration-$(FSTAR_VERSION)
PULSE_INTEGRATION_OBJ_DIR = obj/pulse$(PULSE_INTEGRATION_KIND)-integration-$(FSTAR_VERSION)
PULSE_SHELL_FLAGS = -DISM_USE_PULSE_STREAM=1 -I migration/c $(if $(filter 1,$(PULSE_TABLE_ENABLED)),-DISM_USE_PULSE_TABLE=1) \
                    $(if $(filter 1,$(PULSE_RESPONSE_ENABLED)),-DISM_USE_PULSE_RESPONSE=1)
PULSE_SHELL_OBJECTS = $(PULSE_INTEGRATION_OBJ_DIR)/pulse_stream_adapter.o $(CANDIDATE_STREAM_ARCHIVE) \
                     $(if $(filter 1,$(PULSE_TABLE_ENABLED)),$(PULSE_INTEGRATION_OBJ_DIR)/pulse_table_adapter.o $(CANDIDATE_TABLE_ARCHIVE)) \
                     $(if $(filter 1,$(PULSE_RESPONSE_ENABLED)),$(PULSE_INTEGRATION_OBJ_DIR)/pulse_response_adapter.o $(CANDIDATE_RESPONSE_ARCHIVE))

.PHONY: pulse-stream-artifacts-check pulse-integration-check
pulse-stream-artifacts-check:
	python3 migration/check_stream_artifacts.py check --directory $(CANDIDATE_STREAM_C_DIR) --cc '$(CC)'

.PHONY: pulse-table-artifacts-check pulse-table-integration-check
pulse-table-artifacts-check:
	python3 migration/check_table_artifacts.py check --directory $(CANDIDATE_MULTIPLEXER_C_DIR) --cc '$(CC)'

pulse-table-integration-check: extract pulse-table-artifacts-check
	$(MAKE) -o extract pulse-integration-check PULSE_TABLE_ENABLED=1

.PHONY: pulse-response-artifacts-check pulse-response-integration-check
pulse-response-artifacts-check:
	python3 migration/check_response_artifacts.py check --directory $(CANDIDATE_RESPONSE_C_DIR) --cc '$(CC)'

pulse-response-integration-check: extract pulse-response-artifacts-check
	$(MAKE) -o extract pulse-integration-check PULSE_TABLE_ENABLED=1 PULSE_RESPONSE_ENABLED=1

pulse-integration-check: extract pulse-stream-artifacts-check
	@mkdir -p $(PULSE_INTEGRATION_DIR) $(PULSE_INTEGRATION_OBJ_DIR)
ifeq ($(PULSE_RESPONSE_ENABLED),1)
	python3 migration/check_response_artifacts.py check --directory $(CANDIDATE_RESPONSE_C_DIR) --cc '$(CC)'
	KRML_INCLUDEDIR="$$($(KRML_HOME)/krml -locate-include)"; \
	KRML_LIBDIR="$$($(KRML_HOME)/krml -locate-krmllib)"; \
	$(CC) $(C_SMOKE_CFLAGS) $(PULSE_SHELL_FLAGS) -O2 -Wall -Wextra -Werror \
	  -I "$$KRML_INCLUDEDIR" -I "$$KRML_LIBDIR/dist/minimal" \
	  -c shell/pulse_response_adapter.c -o $(PULSE_INTEGRATION_OBJ_DIR)/pulse_response_adapter.o
endif
ifeq ($(PULSE_TABLE_ENABLED),1)
	python3 migration/check_table_artifacts.py check --directory $(CANDIDATE_MULTIPLEXER_C_DIR) --cc '$(CC)'
	KRML_INCLUDEDIR="$$($(KRML_HOME)/krml -locate-include)"; \
	KRML_LIBDIR="$$($(KRML_HOME)/krml -locate-krmllib)"; \
	$(CC) $(C_SMOKE_CFLAGS) $(PULSE_SHELL_FLAGS) -O2 -Wall -Wextra -Werror \
	  -I "$$KRML_INCLUDEDIR" -I "$$KRML_LIBDIR/dist/minimal" \
	  -c shell/pulse_table_adapter.c -o $(PULSE_INTEGRATION_OBJ_DIR)/pulse_table_adapter.o
endif
	KRML_INCLUDEDIR="$$($(KRML_HOME)/krml -locate-include)"; \
	KRML_LIBDIR="$$($(KRML_HOME)/krml -locate-krmllib)"; \
	$(CC) $(C_SMOKE_CFLAGS) $(PULSE_SHELL_FLAGS) -O2 -Wall -Wextra -Werror \
	  -I "$$KRML_INCLUDEDIR" -I "$$KRML_LIBDIR/dist/minimal" \
	  -c shell/pulse_stream_adapter.c -o $(PULSE_INTEGRATION_OBJ_DIR)/pulse_stream_adapter.o && \
	$(CC) $(C_SMOKE_CFLAGS) $(PULSE_SHELL_FLAGS) -O2 -Wall -Wextra -Werror \
	  -I "$$KRML_INCLUDEDIR" -I "$$KRML_LIBDIR/dist/minimal" \
	  -c shell/ism_shell.c -o $(PULSE_INTEGRATION_OBJ_DIR)/ism_shell.o
	python3 migration/check_stream_artifacts.py selection --object $(PULSE_INTEGRATION_OBJ_DIR)/ism_shell.o
ifeq ($(PULSE_RESPONSE_ENABLED),1)
	python3 migration/check_response_artifacts.py selection --object $(PULSE_INTEGRATION_OBJ_DIR)/ism_shell.o \
	  --adapter $(PULSE_INTEGRATION_OBJ_DIR)/pulse_response_adapter.o
	KRML_INCLUDEDIR="$$($(KRML_HOME)/krml -locate-include)"; \
	KRML_LIBDIR="$$($(KRML_HOME)/krml -locate-krmllib)"; \
	$(CC) $(C_SMOKE_CFLAGS) -I migration/c -I shell -Wall -Wextra -Werror \
	  -I "$$KRML_INCLUDEDIR" -I "$$KRML_LIBDIR/dist/minimal" \
	  migration/c/pulse_response_handoff_smoke.c $(PULSE_INTEGRATION_OBJ_DIR)/pulse_response_adapter.o \
	  $(CANDIDATE_RESPONSE_ARCHIVE) -o $(PULSE_INTEGRATION_DIR)/response-handoff-smoke && \
	$(PULSE_INTEGRATION_DIR)/response-handoff-smoke
	KRML_INCLUDEDIR="$$($(KRML_HOME)/krml -locate-include)"; \
	KRML_LIBDIR="$$($(KRML_HOME)/krml -locate-krmllib)"; \
	$(CC) $(C_SMOKE_CFLAGS) -I migration/c -I shell \
	  -I "$$KRML_INCLUDEDIR" -I "$$KRML_LIBDIR/dist/minimal" \
	  migration/c/pulse_response_differential.c migration/c/legacy_shell_oracle.c \
	  shell/link_krml_compat_stubs.c shell/link_everparse_smoke.c \
	  $(C_COMPILE_SMOKE_SOURCES) $(PULSE_INTEGRATION_OBJ_DIR)/ism_shell.o $(PULSE_SHELL_OBJECTS) \
	  -o $(PULSE_INTEGRATION_DIR)/response-differential && $(PULSE_INTEGRATION_DIR)/response-differential
endif
ifeq ($(PULSE_TABLE_ENABLED),1)
	python3 migration/check_table_artifacts.py selection --object $(PULSE_INTEGRATION_OBJ_DIR)/ism_shell.o \
	  --adapter $(PULSE_INTEGRATION_OBJ_DIR)/pulse_table_adapter.o
	KRML_INCLUDEDIR="$$($(KRML_HOME)/krml -locate-include)"; \
	KRML_LIBDIR="$$($(KRML_HOME)/krml -locate-krmllib)"; \
	$(CC) $(C_SMOKE_CFLAGS) -I migration/c -I shell \
	  -I "$$KRML_INCLUDEDIR" -I "$$KRML_LIBDIR/dist/minimal" \
	  migration/c/pulse_table_differential.c migration/c/legacy_shell_oracle.c \
	  shell/link_krml_compat_stubs.c shell/link_everparse_smoke.c \
	  $(C_COMPILE_SMOKE_SOURCES) $(PULSE_INTEGRATION_OBJ_DIR)/ism_shell.o $(PULSE_SHELL_OBJECTS) \
	  -o $(PULSE_INTEGRATION_DIR)/table-differential && $(PULSE_INTEGRATION_DIR)/table-differential
endif
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

# Paths to your F* and KaRaMel installations
FSTAR_HOME  ?= /opt/fstar/fstar
KRML_HOME   ?= /opt/karamel
INCLUDE_DIR = $(FSTAR_HOME)/ulib/.cache

# Project Directories
SRC_DIRS    = src/protocol src/security src/transport src/logic src/concurrency spec
OBJ_DIR     = obj
DIST_DIR    = dist
GENERATED_DIR = generated
EVERPARSE_SRC_DIR = everparse
EVERPARSE_OUT_DIR = $(GENERATED_DIR)/everparse
EVERPARSE_CMD ?= everparse.sh
EVERPARSE_HOME ?= /opt/everparse
EVERPARSE_INCLUDE_DIRS = $(EVERPARSE_OUT_DIR) \
                         $(EVERPARSE_HOME)/src/3d/prelude/buffer \
                         $(EVERPARSE_HOME)/src/3d/prelude \
                         $(EVERPARSE_HOME)/src/lowparse \
                         $(EVERPARSE_HOME)/krmllib \
                         $(EVERPARSE_HOME)/krmllib/obj

# F* configuration
FSTAR_OPTS  = --odir $(OBJ_DIR) --cache_dir $(OBJ_DIR) \
              $(addprefix --include , $(SRC_DIRS))

EVERPARSE_FSTAR_OPTS = --odir $(EVERPARSE_OUT_DIR) --cache_dir $(EVERPARSE_OUT_DIR) \
                       $(addprefix --include , $(EVERPARSE_INCLUDE_DIRS)) \
                       --already_cached 'Prims,LowStar,FStar,LowParse,C,EverParse3d.*,Spec'

# KaRaMel configuration
KRML_OPTS   = -drop 'FStar.Tactics.*' -drop 'FStar.Reflection.*' \
              -bundle DNS.Protocol=DNS.Protocol,DNS.Name,DNS.Constants,DNS.RCode,DNS.Protocol.* \
              -bundle DNS.Security.*,DNS.QUIC.*,DNS.Zone.RadixTree,DNS.Worker,DNS.ShellScheduler \
              -tmpdir $(DIST_DIR) -skip-compilation

# C syntax smoke gate for generated artifacts. This deliberately stops short of
# linking a runnable shell; it checks that the current extracted C surface and
# EverParse wrapper are consumable by a C compiler.
CC ?= cc
C_COMPILE_SMOKE_CFLAGS = -std=c11 -D_DEFAULT_SOURCE -D_BSD_SOURCE -fsyntax-only \
                         -I $(DIST_DIR) \
                         -I $(DIST_DIR)/internal \
                         -I $(EVERPARSE_OUT_DIR) \
                         -I $(EVERPARSE_HOME)/krmllib/dist/minimal \
                         -I $(EVERPARSE_HOME)/src/3d/prelude \
                         -I $(EVERPARSE_HOME)/src/3d/prelude/buffer
C_COMPILE_SMOKE_SOURCES = $(DIST_DIR)/DNS_Protocol.c \
                          $(EVERPARSE_OUT_DIR)/DNSProtocol.c \
                          $(EVERPARSE_OUT_DIR)/DNSProtocolWrapper.c

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
                    $(wildcard spec/*.fsti)

EVERPARSE_3D_FILES = $(wildcard $(EVERPARSE_SRC_DIR)/*.3d)

.PHONY: all verify extract c-compile-smoke everparse-generate everparse-verify clean

all: extract

# 2. Verification Stage
# We verify each file individually to ensure we see the specific errors.
# We no longer rely on complex .depend for this bootstrap phase.
verify:
	@mkdir -p $(OBJ_DIR)
	@echo "Verifying Source Files..."
	$(FSTAR_HOME)/bin/fstar.exe $(FSTAR_OPTS) $(ALL_FST_FILES)

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

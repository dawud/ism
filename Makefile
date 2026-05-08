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

# F* configuration
FSTAR_OPTS  = --odir $(OBJ_DIR) --cache_dir $(OBJ_DIR) \
              $(addprefix --include , $(SRC_DIRS))

# KaRaMel configuration
KRML_OPTS   = -drop 'FStar.Tactics.*' -drop 'FStar.Reflection.*' \
              -bundle DNS.Protocol=DNS.Protocol,DNS.Name,DNS.Constants,DNS.RCode,DNS.Protocol.* \
              -bundle DNS.Security.*,DNS.QUIC.* \
              -tmpdir $(DIST_DIR) -skip-compilation

# 1. Collect all F* source files
ALL_FST_FILES = $(wildcard src/protocol/*.fst) \
                $(wildcard src/security/*.fst) \
                $(wildcard src/transport/*.fst) \
                $(wildcard src/logic/*.fst) \
                $(wildcard src/concurrency/*.fst) \
                $(wildcard spec/*.fsti)

# Extraction is narrower than verification while Phase 3/4 scaffolds still
# contain specification-oriented lists, admits, and Steel placeholders.
EXTRACT_FST_FILES = $(filter-out src/protocol/%.Tests.fst, $(wildcard src/protocol/*.fst)) \
                    $(wildcard src/security/*.fst) \
                    $(wildcard src/transport/*.fst) \
                    $(wildcard spec/*.fsti)

EVERPARSE_3D_FILES = $(wildcard $(EVERPARSE_SRC_DIR)/*.3d)

.PHONY: all verify extract everparse-generate clean

all: extract

# 2. Verification Stage
# We verify each file individually to ensure we see the specific errors.
# We no longer rely on complex .depend for this bootstrap phase.
verify:
	@mkdir -p $(OBJ_DIR)
	@echo "Verifying Source Files..."
	$(FSTAR_HOME)/bin/fstar.exe $(FSTAR_OPTS) $(ALL_FST_FILES)

# 3. Extraction Stage
extract: verify
	@echo "Extracting to C in $(DIST_DIR)..."
	mkdir -p $(DIST_DIR)
	$(KRML_HOME)/krml $(KRML_OPTS) $(EXTRACT_FST_FILES)

# 4. EverParse generation scaffold
everparse-generate:
	@mkdir -p $(EVERPARSE_OUT_DIR)
	@command -v $(EVERPARSE_CMD) >/dev/null 2>&1 || { \
		echo "EverParse command '$(EVERPARSE_CMD)' was not found."; \
		echo "Set EVERPARSE_CMD to everparse.sh or bin/3d.exe from an EverParse release."; \
		exit 127; \
	}
	$(EVERPARSE_CMD) --odir $(EVERPARSE_OUT_DIR) --no_clang_format $(EVERPARSE_3D_FILES)

# 4. Cleanup
clean:
	rm -rf $(OBJ_DIR) $(DIST_DIR) $(GENERATED_DIR) .depend

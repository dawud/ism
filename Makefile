# Paths to your F* and KaRaMel installations
FSTAR_HOME  ?= /opt/fstar/fstar
KRML_HOME   ?= /opt/karamel
INCLUDE_DIR = $(FSTAR_HOME)/ulib/.cache

# Project Directories
SRC_DIRS    = src/protocol src/security src/transport src/logic src/concurrency spec
OBJ_DIR     = obj
DIST_DIR    = dist

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

.PHONY: all verify extract clean

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

# 4. Cleanup
clean:
	rm -rf $(OBJ_DIR) $(DIST_DIR) .depend

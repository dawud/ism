include migration/toolchain.lock

CANDIDATE_LANE = candidate-$(FSTAR_VERSION)
CANDIDATE_OBJ_DIR = obj/$(CANDIDATE_LANE)
CANDIDATE_DIST_DIR = dist/$(CANDIDATE_LANE)
CANDIDATE_C_DIR = $(CANDIDATE_DIST_DIR)/pulse-c
CANDIDATE_Z3 = $(FSTAR_HOME)/lib/fstar/z3-$(Z3_VERSION)/bin/z3
CANDIDATE_FSTAR_OPTS = --z3version $(Z3_VERSION) --smt $(CANDIDATE_Z3) \
                      --cache_checked_modules

.PHONY: candidate-check candidate-toolchain-check candidate-verify candidate-extract \
        candidate-c-smoke migration-inventory-check

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
	  > $(CANDIDATE_DIST_DIR)/inventory.json.tmp
	@mv $(CANDIDATE_DIST_DIR)/inventory.json.tmp $(CANDIDATE_DIST_DIR)/inventory.json
	@echo "Migration inventory checked; see $(CANDIDATE_DIST_DIR)/inventory.json"

candidate-verify: candidate-toolchain-check
	$(MAKE) verify-pulse-pilot BUILD_LANE=$(CANDIDATE_LANE) \
	  PULSE_PILOT_FSTAR_OPTS='--odir $(CANDIDATE_OBJ_DIR)/pulse-pilot \
	    --cache_dir $(CANDIDATE_OBJ_DIR)/pulse-pilot $(CANDIDATE_FSTAR_OPTS) \
	    $(addprefix --include ,$(PULSE_INCLUDE_DIRS))'

# M1 exercises the bundled F*/KaRaMeL C path on an existing pure value pilot.
# Real reference/buffer extraction and shell integration are M3, not claimed here.
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

candidate-check: migration-inventory-check candidate-c-smoke

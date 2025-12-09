# Build CCStudio 12.8 on Ubuntu 24.04
.PHONY: 12.8-ubuntu24.04
12.8-ubuntu24.04:
	# You can override components via env: CCS_COMPONENTS, MMWSDK_VERSION, MMWSDK_COMPONENTS, BIOS_VERSION
	# Defaults: install all CCS components, no mmWave SDK, no SYS/BIOS
	@echo "Building ccstudio:12.8-ubuntu24.04..."
	$(eval UBUNTU_VERSION := 24.04)
	$(eval CCSTUDIO_VERSION := 12.8.1.00005)
	$(eval CCS_VERSION_SHORT := 12.8)
	$(eval CCS_COMPONENTS := $(or ${CCS_COMPONENTS},PF_ALL))
	# Explicitly disable mmWave SDK by default
	$(eval MMWSDK_VERSION := )
	$(eval MMWSDK_COMPONENTS := )
	# Enable SYS/BIOS by default (tested 6.73.01.01)
	$(eval BIOS_VERSION := $(or ${BIOS_VERSION},6.73.01.01))
	$(eval tag := ccstudio:$(CCS_VERSION_SHORT)-ubuntu$(UBUNTU_VERSION))
	docker build -t $(tag) . \
 		--build-arg "OS_VERSION=$(UBUNTU_VERSION)" \
 		--build-arg "CCS_VERSION=$(CCSTUDIO_VERSION)" \
 		--build-arg "CCS_COMPONENTS=$(CCS_COMPONENTS)" \
 		--build-arg "MMWSDK_VERSION=$(MMWSDK_VERSION)" \
 		--build-arg "MMWSDK_COMPONENTS=$(MMWSDK_COMPONENTS)" \
		--build-arg "BIOS_VERSION=$(BIOS_VERSION)" \
		--build-arg "GUI_DEPS=$(or ${GUI_DEPS},0)"

.PHONY: 12.8-ubuntu24.04-gui
12.8-ubuntu24.04-gui:
	@echo "Building ccstudio:12.8-ubuntu24.04-gui (GUI deps enabled)..."
	$(eval UBUNTU_VERSION := 24.04)
	$(eval CCSTUDIO_VERSION := 12.8.1.00005)
	$(eval CCS_VERSION_SHORT := 12.8)
	$(eval CCS_COMPONENTS := $(or ${CCS_COMPONENTS},PF_ALL))
	$(eval BIOS_VERSION := $(or ${BIOS_VERSION},6.73.01.01))
	$(eval tag := ccstudio:$(CCS_VERSION_SHORT)-ubuntu$(UBUNTU_VERSION)-gui)
	docker build -t $(tag) . \
		--build-arg "OS_VERSION=$(UBUNTU_VERSION)" \
		--build-arg "CCS_VERSION=$(CCSTUDIO_VERSION)" \
		--build-arg "CCS_COMPONENTS=$(CCS_COMPONENTS)" \
		--build-arg "MMWSDK_VERSION=" \
		--build-arg "MMWSDK_COMPONENTS=" \
		--build-arg "BIOS_VERSION=$(BIOS_VERSION)" \
		--build-arg "GUI_DEPS=1"

.PHONY: run-x11-gui
run-x11-gui:
	@echo "Launching CCS GUI via X11 (GUI image)..."
	# Accept WORKSPACE_DIR and PROJECTS_DIR from environment; fallback to defaults
	bash scripts/run_x11.sh ccstudio:12.8-ubuntu24.04-gui "$(or ${WORKSPACE_DIR},$(HOME)/ccs-workspace)" "${PROJECTS_DIR}" "${PRODUCTS_DIR}"

.PHONY: run-x11
run-x11:
	@echo "Launching CCS GUI via X11..."
	# Accept WORKSPACE_DIR and PROJECTS_DIR from environment; fallback to defaults
	bash scripts/run_x11.sh ccstudio:12.8-ubuntu24.04 "$(or ${WORKSPACE_DIR},$(HOME)/ccs-workspace)" "${PROJECTS_DIR}" "${PRODUCTS_DIR}"

# ==== Configuration ====
DOCKER_REPO := whuzfb/ccstudio

UBUNTU_VERSIONS := 20.04 22.04 24.04
CCS_VERSIONS := 10.4.0.00006 11.2.0.00007 12.8.1.00005 20.2.0.00012

# PF_MMWAVE,PF_C6000SC,PF_TM4C,...,PF_ALL
CCS_COMPONENTS := PF_ALL
# 03.06.02.00-LTS
MMWSDK_VERSION := 03.06.02.00-LTS
# ..., ALL
MMWSDK_COMPONENTS := ALL
BIOS_VERSION :=

# ==== Derived Variables ====
TAG_SUFFIX := $(if $(and $(strip $(MMWSDK_VERSION)),$(strip $(MMWSDK_COMPONENTS))),-mmw,)

# ==== Utilities ====
define build_image
	@echo "🔧 Building image for CCS=$(2), Ubuntu=$(1)"
	docker build -t $(DOCKER_REPO):$(3)-ubuntu$(1)$(TAG_SUFFIX) . \
		--build-arg OS_VERSION="$(1)" \
		--build-arg CCS_VERSION="$(2)" \
		--build-arg CCS_COMPONENTS="$(CCS_COMPONENTS)" \
		$(if $(BIOS_VERSION),--build-arg BIOS_VERSION="$(BIOS_VERSION)") \
		--build-arg MMWSDK_VERSION="$(MMWSDK_VERSION)" \
		--build-arg MMWSDK_COMPONENTS="$(MMWSDK_COMPONENTS)"
endef

# ==== Targets Generation ====
BUILD_TARGETS :=

# Create one target per (ubuntu, ccs) combination
$(foreach CCS,$(CCS_VERSIONS), \
  $(foreach UBUNTU,$(UBUNTU_VERSIONS), \
    $(eval CCS_SHORT := $(shell echo $(CCS) | cut -d. -f1-2)) \
    $(eval TARGET_NAME := ubuntu$(UBUNTU)-$(CCS)$(TAG_SUFFIX)) \
    $(eval BUILD_TARGETS += $(TARGET_NAME)) \
  ) \
)

# Generate target rules
$(foreach CCS,$(CCS_VERSIONS), \
  $(foreach UBUNTU,$(UBUNTU_VERSIONS), \
    $(eval CCS_SHORT := $(shell echo $(CCS) | cut -d. -f1-2)) \
    $(eval TARGET_NAME := ubuntu$(UBUNTU)-$(CCS)$(TAG_SUFFIX)) \
    $(eval $(TARGET_NAME): ; $(call build_image,$(UBUNTU),$(CCS),$(CCS_SHORT))) \
  ) \
)

# ==== Main targets ====

all: $(BUILD_TARGETS)

gen_compose:
	@{ \
	echo "services:"; \
	for CCS in $(CCS_VERSIONS); do \
	  for UBUNTU in $(UBUNTU_VERSIONS); do \
	    CCS_SHORT=$$(echo $$CCS | cut -d. -f1-2); \
	    TAG_SUFFIX=""; \
	    [ -n "$(MMWSDK_VERSION)" ] && [ -n "$(MMWSDK_COMPONENTS)" ] && TAG_SUFFIX="-mmw"; \
	    TARGET="ubuntu$${UBUNTU}-$${CCS}$$TAG_SUFFIX"; \
	    echo "  $$TARGET:"; \
	    echo "    build:"; \
	    echo "      context: ."; \
	    echo "      args:"; \
	    echo "        OS_VERSION: \"$$UBUNTU\""; \
	    echo "        CCS_VERSION: \"$$CCS\""; \
	    echo "        CCS_COMPONENTS: \"$(CCS_COMPONENTS)\""; \
	    [ -n "$(BIOS_VERSION)" ] && echo "        BIOS_VERSION: \"$(BIOS_VERSION)\""; \
	    echo "        MMWSDK_VERSION: \"$(MMWSDK_VERSION)\""; \
	    echo "        MMWSDK_COMPONENTS: \"$(MMWSDK_COMPONENTS)\""; \
	    echo "    image: $(DOCKER_REPO):$${CCS_SHORT}-ubuntu$${UBUNTU}$$TAG_SUFFIX"; \
	  done; \
	done; \
	} > docker-compose.yaml

list:
	@echo "Available build targets:"
	@$(foreach t,$(BUILD_TARGETS),echo "  $(t)";)

clean:
	@echo "Nothing to clean for now."

.PHONY: all clean list $(BUILD_TARGETS)

%:
	@echo "Unknown target: '$@'"
	@echo "Available targets:"
	@$(foreach t,$(BUILD_TARGETS),echo "   $(t)";)
	@false

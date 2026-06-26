# ─────────────────────────────────────────────────────────────────────────────
#  Agendum Data — quickstart Makefile
#  Reproduces the README "get-started" flow: curl the public docker-compose.yml,
#  run it with docker compose, and smoke-test everything the README advertises.
# ─────────────────────────────────────────────────────────────────────────────

COMPOSE_URL  ?= https://raw.githubusercontent.com/AgendumData/docker/main/docker-compose.yml
BUILD_DIR    ?= .agendum-data
COMPOSE_FILE := $(BUILD_DIR)/docker-compose.yml
SERVICE      ?= agendum

# Every docker compose call runs from inside $(BUILD_DIR), so the commands are
# the plain ones you can reproduce by hand:  cd $(BUILD_DIR) && docker compose ...
# (default project name + default compose file — nothing to remember).

API_URL      ?= http://localhost:8800
EXPLORER_URL ?= http://localhost:8801

# Exact version string the running image must expose at /version.txt.
EXPECTED_VERSION ?= agendum-0.1.0

# How long to wait for a service to answer before giving up (seconds).
WAIT_TIMEOUT ?= 120

.DEFAULT_GOAL := help

# ── meta ─────────────────────────────────────────────────────────────────────

.PHONY: help
help: ## Show this help
	@echo ""
	@echo "  Agendum Data — headless CRM quickstart"
	@echo "  ─────────────────────────────────────"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ── download ─────────────────────────────────────────────────────────────────

.PHONY: download
download: $(COMPOSE_FILE) ## Curl the public docker-compose.yml (the README one-liner)

$(COMPOSE_FILE):
	@mkdir -p $(BUILD_DIR)
	@echo "==> Downloading docker-compose.yml from $(COMPOSE_URL)"
	@if curl -fSL -o $(COMPOSE_FILE) $(COMPOSE_URL) 2>/dev/null; then \
		echo "==> Saved to $(COMPOSE_FILE)"; \
	elif [ -f docker-compose.yml ]; then \
		echo "!!  Public URL not reachable yet — falling back to local ./docker-compose.yml"; \
		cp docker-compose.yml $(COMPOSE_FILE); \
		echo "==> Copied to $(COMPOSE_FILE)"; \
	else \
		echo "❌  Could not download $(COMPOSE_URL) and no local docker-compose.yml found"; exit 1; \
	fi

# ── lifecycle ────────────────────────────────────────────────────────────────

.PHONY: up
up: download ## Download + start the stack in the background
	@echo "==> Starting Agendum Data stack"
	@cd $(BUILD_DIR) && docker compose up -d
	@echo "==> API:      $(API_URL)"
	@echo "==> Explorer: $(EXPLORER_URL)"

.PHONY: migrate
migrate: ## Run the first-time database migration (creates all tables)
	@echo "==> Migrating database (first-run)"
	@cd $(BUILD_DIR) && docker compose exec -T $(SERVICE) migrate --wait-database

.PHONY: down
down: ## Stop and remove the stack (keeps volumes)
	@if [ -f $(COMPOSE_FILE) ]; then cd $(BUILD_DIR) && docker compose down --remove-orphans; else echo "Nothing to stop."; fi

.PHONY: logs
logs: ## Tail the stack logs
	@cd $(BUILD_DIR) && docker compose logs -f agendum

.PHONY: shell
shell: ## Tail the stack logs
	@cd $(BUILD_DIR) && docker compose exec agendum bash

.PHONY: ps
ps: ## Show running services
	@cd $(BUILD_DIR) && docker compose ps

# ── test ─────────────────────────────────────────────────────────────────────

.PHONY: test
test: up ## Full quickstart smoke test (download → run → migrate → verify)
	@BUILD_DIR='$(BUILD_DIR)' SERVICE='$(SERVICE)' \
		API_URL='$(API_URL)' EXPLORER_URL='$(EXPLORER_URL)' \
		EXPECTED_VERSION='$(EXPECTED_VERSION)' WAIT_TIMEOUT='$(WAIT_TIMEOUT)' \
		bash test.sh

# ── cleanup ──────────────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Stop the stack, drop volumes, remove the downloaded compose file
	@if [ -f $(COMPOSE_FILE) ]; then cd $(BUILD_DIR) && docker compose down -v --remove-orphans; fi
	@rm -rf $(BUILD_DIR)
	@echo "==> Cleaned up containers, volumes and $(BUILD_DIR)"
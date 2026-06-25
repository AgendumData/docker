# ─────────────────────────────────────────────────────────────────────────────
#  Agendum Data — quickstart Makefile
#  Reproduces the README "get-started" flow: curl the public docker-compose.yml,
#  run it with docker compose, and smoke-test everything the README advertises.
# ─────────────────────────────────────────────────────────────────────────────

COMPOSE_URL  ?= https://raw.githubusercontent.com/AgendumData/docker/main/docker-compose.yml
BUILD_DIR    ?= .agendum
COMPOSE_FILE := $(BUILD_DIR)/docker-compose.yml
PROJECT      ?= agendum-quickstart

DC           := docker compose -p $(PROJECT) -f $(COMPOSE_FILE)
SERVICE      ?= agendum

API_URL      ?= http://localhost:8800
EXPLORER_URL ?= http://localhost:8801

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
	@$(DC) up -d
	@echo "==> API:      $(API_URL)"
	@echo "==> Explorer: $(EXPLORER_URL)"

.PHONY: migrate
migrate: ## Run the first-time database migration (creates all tables)
	@echo "==> Migrating database (first-run); retrying until the DB is ready"
	@end=$$(( $$(date +%s) + $(WAIT_TIMEOUT) )); \
	until $(DC) exec -T $(SERVICE) migrate; do \
		if [ $$(date +%s) -ge $$end ]; then \
			echo "❌  migration did not complete in $(WAIT_TIMEOUT)s"; $(DC) logs $(SERVICE); exit 1; \
		fi; \
		echo "    ...database not ready yet, retrying"; sleep 3; \
	done

.PHONY: down
down: ## Stop and remove the stack (keeps volumes)
	@if [ -f $(COMPOSE_FILE) ]; then $(DC) down; else echo "Nothing to stop."; fi

.PHONY: logs
logs: ## Tail the stack logs
	@$(DC) logs -f

.PHONY: ps
ps: ## Show running services
	@$(DC) ps

# ── test ─────────────────────────────────────────────────────────────────────

.PHONY: test
test: up wait-api migrate wait-boot wait-explorer ## Full quickstart smoke test (download → run → migrate → verify)
	@echo ""
	@echo "==> Verifying the README claims"
	@$(MAKE) --no-print-directory check-api
	@$(MAKE) --no-print-directory check-graphql
	@$(MAKE) --no-print-directory check-mcp
	@$(MAKE) --no-print-directory check-llms
	@$(MAKE) --no-print-directory check-explorer
	@echo ""
	@echo "✅  Agendum Data quickstart verified — everything in the README works."

.PHONY: wait-api
wait-api: ## Block until the API container answers (boot splash)
	@echo "==> Waiting for the API at $(API_URL) (up to $(WAIT_TIMEOUT)s)"
	@end=$$(( $$(date +%s) + $(WAIT_TIMEOUT) )); \
	until curl -fsS -o /dev/null "$(API_URL)"; do \
		if [ $$(date +%s) -ge $$end ]; then \
			echo "❌  API did not come up in $(WAIT_TIMEOUT)s"; $(DC) logs $(SERVICE); exit 1; \
		fi; \
		printf '.'; sleep 2; \
	done; echo " ok"

.PHONY: wait-boot
wait-boot: ## Block until the app is fully booted (llms.txt manifest served)
	@echo "==> Waiting for Agendum to finish booting (up to $(WAIT_TIMEOUT)s)"
	@end=$$(( $$(date +%s) + $(WAIT_TIMEOUT) )); \
	until [ "$$(curl -s -o /dev/null -w '%{http_code}' "$(API_URL)/llms.txt")" = "200" ]; do \
		if [ $$(date +%s) -ge $$end ]; then \
			echo "❌  app still booting after $(WAIT_TIMEOUT)s"; $(DC) logs $(SERVICE); exit 1; \
		fi; \
		printf '.'; sleep 2; \
	done; echo " ok"

.PHONY: wait-explorer
wait-explorer: ## Block until the GraphQL Explorer answers
	@echo "==> Waiting for the GraphQL Explorer at $(EXPLORER_URL) (up to $(WAIT_TIMEOUT)s)"
	@end=$$(( $$(date +%s) + $(WAIT_TIMEOUT) )); \
	until curl -fsS -o /dev/null "$(EXPLORER_URL)"; do \
		if [ $$(date +%s) -ge $$end ]; then \
			echo "❌  Explorer did not come up in $(WAIT_TIMEOUT)s"; $(DC) logs graphql-explorer; exit 1; \
		fi; \
		printf '.'; sleep 2; \
	done; echo " ok"

.PHONY: check-api
check-api: ## Probe the API root
	@code=$$(curl -s -o /dev/null -w '%{http_code}' "$(API_URL)"); \
	echo "    API root         $(API_URL)  ->  HTTP $$code"; \
	case $$code in 2*|3*|4*) ;; *) echo "❌  API unreachable"; exit 1;; esac

.PHONY: check-graphql
check-graphql: ## Probe the GraphQL endpoint with an introspection query
	@code=$$(curl -s -o /dev/null -w '%{http_code}' \
		-X POST "$(API_URL)/graphql" \
		-H 'Content-Type: application/json' \
		--data '{"query":"{ __typename }"}'); \
	echo "    GraphQL API      $(API_URL)/graphql  ->  HTTP $$code"; \
	case $$code in 2*) ;; *) echo "❌  GraphQL endpoint not healthy"; exit 1;; esac

.PHONY: check-mcp
check-mcp: ## Probe the MCP server endpoint
	@code=$$(curl -s -o /dev/null -w '%{http_code}' "$(API_URL)/mcp"); \
	echo "    MCP server       $(API_URL)/mcp  ->  HTTP $$code"; \
	case $$code in 2*|3*|4*) ;; *) echo "❌  MCP endpoint unreachable"; exit 1;; esac

.PHONY: check-llms
check-llms: ## Probe the self-describing llms.txt manifest
	@code=$$(curl -s -o /dev/null -w '%{http_code}' "$(API_URL)/llms.txt"); \
	echo "    llms.txt         $(API_URL)/llms.txt  ->  HTTP $$code"; \
	case $$code in 2*) ;; *) echo "❌  llms.txt not served"; exit 1;; esac

.PHONY: check-explorer
check-explorer: ## Probe the GraphQL Explorer UI
	@code=$$(curl -s -o /dev/null -w '%{http_code}' "$(EXPLORER_URL)"); \
	echo "    GraphQL Explorer $(EXPLORER_URL)  ->  HTTP $$code"; \
	case $$code in 2*|3*) ;; *) echo "❌  Explorer unreachable"; exit 1;; esac

# ── cleanup ──────────────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Stop the stack, drop volumes, remove the downloaded compose file
	@if [ -f $(COMPOSE_FILE) ]; then $(DC) down -v --remove-orphans; fi
	@rm -rf $(BUILD_DIR)
	@echo "==> Cleaned up containers, volumes and $(BUILD_DIR)"
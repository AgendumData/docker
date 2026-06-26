#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Agendum Data — quickstart smoke test
#  Boot-aware end-to-end check: waits for the stack, runs the first migration,
#  then verifies every endpoint the README advertises.
#
#  Driven by `make test`, but trivially runnable / debuggable by hand:
#      cd .agendum-data && docker compose ps      # the stack lives here
#      bash test.sh                               # re-run the checks
#  Every docker compose call below runs from inside $BUILD_DIR with the default
#  project name and default compose file — the exact commands you'd type.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── config (overridable via env, defaults mirror the Makefile) ────────────────
BUILD_DIR="${BUILD_DIR:-.agendum-data}"
SERVICE="${SERVICE:-agendum}"
API_URL="${API_URL:-http://localhost:8800}"
EXPLORER_URL="${EXPLORER_URL:-http://localhost:8801}"
EXPECTED_VERSION="${EXPECTED_VERSION:-agendum-0.1.0}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-120}"

# Run from inside the stack directory so every command is a plain
# `docker compose ...` you can reproduce after a `cd $BUILD_DIR`.
cd "$BUILD_DIR"

# ── helpers ───────────────────────────────────────────────────────────────────

die() { echo ""; echo "❌  $*"; exit 1; }

# wait_until "label" "logs-service" <command...>  — retry the command until it succeeds
wait_until() {
	local label="$1" logs_service="$2"; shift 2
	echo "==> Waiting for $label (up to ${WAIT_TIMEOUT}s)"
	local end=$(( $(date +%s) + WAIT_TIMEOUT ))
	until "$@"; do
		if [ "$(date +%s)" -ge "$end" ]; then
			docker compose logs "$logs_service" || true
			die "$label did not come up in ${WAIT_TIMEOUT}s"
		fi
		printf '.'; sleep 2
	done
	echo " ok"
}

# expect_http "label" URL "accepted-code-glob" [curl args...]  — probe and assert status
expect_http() {
	local label="$1" url="$2" accept="$3"; shift 3
	local code; code="$(curl -s -o /dev/null -w '%{http_code}' "$@" "$url")"
	printf '    %-16s %s  ->  HTTP %s\n' "$label" "$url" "$code"
	# shellcheck disable=SC2254
	case "$code" in
		$accept) ;;
		*) die "$label not healthy (HTTP $code)";;
	esac
}

# ── flow ──────────────────────────────────────────────────────────────────────

# 1. API container answering (boot splash is enough)
wait_until "the API at $API_URL" "$SERVICE" \
	curl -fsS -o /dev/null "$API_URL"

# 2. First-run migration (the image waits for the DB itself)
echo "==> Migrating database (first-run)"
docker compose exec -T "$SERVICE" migrate --wait-database

# 3. App fully booted (llms.txt manifest served)
wait_until "Agendum to finish booting" "$SERVICE" \
	bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' '$API_URL/llms.txt')\" = 200 ]"

# 4. GraphQL Explorer answering
wait_until "the GraphQL Explorer at $EXPLORER_URL" graphql-explorer \
	curl -fsS -o /dev/null "$EXPLORER_URL"

# ── verification ──────────────────────────────────────────────────────────────
echo ""
echo "==> Verifying the README claims"

# Version must match exactly
version="$(curl -s "$API_URL/version.txt" | tr -d '[:space:]')"
printf '    %-16s %s  ->  %s\n' "Version" "$API_URL/version.txt" "'$version'"
if [ "$version" = "$EXPECTED_VERSION" ]; then
	echo "    ✓ version matches $EXPECTED_VERSION"
else
	echo ""
	echo "❌  Version mismatch: expected '$EXPECTED_VERSION', got '$version'."
	echo "    👉  Update the image:  cd $BUILD_DIR && docker compose pull $SERVICE && cd - && make clean && make test"
	exit 1
fi

expect_http "API root"         "$API_URL"          '2*|3*|4*'
expect_http "GraphQL API"      "$API_URL/graphql"  '2*' \
	-X POST -H 'Content-Type: application/json' --data '{"query":"{ __typename }"}'
expect_http "MCP server"       "$API_URL/mcp"      '2*|3*|4*'
expect_http "llms.txt"         "$API_URL/llms.txt" '2*'
expect_http "GraphQL Explorer" "$EXPLORER_URL"     '2*|3*'

echo ""
echo "✅  Agendum Data quickstart verified — everything in the README works."
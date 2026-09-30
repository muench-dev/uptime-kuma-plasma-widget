#!/usr/bin/env bash
set -euo pipefail

# Helper script to run Uptime Kuma integration tests against a real Docker instance.
# Usage:
#   ./tests/run-docker-test.sh v1
#   ./tests/run-docker-test.sh v2

VERSION="${1:-v2}"
CONTAINER_NAME="kuma-test-runner-${VERSION}-$$"
HOST_PORT="${PORT:-13005}"

if [ "$VERSION" = "v1" ]; then
    IMAGE="louislam/uptime-kuma:1.23.16"
    ENV_ARGS=()
elif [ "$VERSION" = "v2" ]; then
    IMAGE="louislam/uptime-kuma:2"
    ENV_ARGS=("-e" "UPTIME_KUMA_DB_TYPE=sqlite")
else
    echo "Unknown version '$VERSION'. Use 'v1' or 'v2'."
    exit 1
fi

cleanup() {
    echo "Cleaning up container $CONTAINER_NAME..."
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

echo "==> Starting $VERSION container ($IMAGE) on port $HOST_PORT..."
docker run -d --name "$CONTAINER_NAME" \
    "${ENV_ARGS[@]}" \
    -p "$HOST_PORT:3001" \
    "$IMAGE" >/dev/null

echo "==> Waiting for server to initialize..."
for i in $(seq 1 45); do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$HOST_PORT/" || true)
    if [ "$CODE" = "200" ] || [ "$CODE" = "302" ]; then
        echo "Server is responding (HTTP $CODE) after ${i}s."
        break
    fi
    sleep 1
done

echo "==> Seeding database..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
docker exec -i "$CONTAINER_NAME" sqlite3 /app/data/kuma.db < "$SCRIPT_DIR/fixtures/seed.sql"

echo "==> Restarting container to reload cache..."
docker restart "$CONTAINER_NAME" >/dev/null

echo "==> Waiting for status page to be ready..."
for i in $(seq 1 30); do
    if curl -s "http://127.0.0.1:$HOST_PORT/api/status-page/default" | grep -q "Production Services"; then
        echo "Status page ready after ${i}s."
        break
    fi
    sleep 1
done

echo "==> Running integration tests against $VERSION..."
KUMA_URL="http://127.0.0.1:$HOST_PORT" \
KUMA_API_KEY="uk1_mysecretkey" \
node --test "$SCRIPT_DIR/integration.test.js"

echo "✅ $VERSION integration tests passed successfully!"

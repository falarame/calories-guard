#!/usr/bin/env bash
# Boot Ollama and ensure the configured model is present before declaring ready.
set -euo pipefail

MODEL="${OLLAMA_PRELOAD_MODEL:-deepseek-r1:8b}"

ollama serve &
SERVER_PID=$!

# Wait for the HTTP API to come up
for i in {1..60}; do
  if ollama list >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! ollama list | awk 'NR>1 {print $1}' | grep -qx "${MODEL}"; then
  echo "[entrypoint] Pulling ${MODEL} (first run only — may take several minutes)..."
  ollama pull "${MODEL}"
fi

echo "[entrypoint] Ready. Model ${MODEL} available."
wait "${SERVER_PID}"

#!/usr/bin/env bash
# CI orchestration script for FlexCoins
# Runs: lint -> unit tests -> launch game -> E2E sequences -> shutdown
# Exit on first failure
set -euo pipefail

GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVTOOLS="python3 ${PROJECT_DIR}/tools/devtools.py"
EXIT_CODE=0

echo "============================================"
echo "  FlexCoins CI Test Suite"
echo "============================================"
echo ""

# --------------------------------------------
# Phase 1: Headless Lint
# --------------------------------------------
echo "[Phase 1/4] Running headless lint..."
if "${GODOT}" --headless --path "${PROJECT_DIR}" --script res://tools/lint_project.gd -- --all --fail-on-warn; then
    echo "[Phase 1/4] Lint: PASSED"
else
    echo "[Phase 1/4] Lint: FAILED"
    EXIT_CODE=1
fi
echo ""

# --------------------------------------------
# Phase 2: Unit Tests
# --------------------------------------------
echo "[Phase 2/4] Running unit tests..."
if "${GODOT}" --headless --path "${PROJECT_DIR}" --script res://tools/run_tests.gd; then
    echo "[Phase 2/4] Unit tests: PASSED"
else
    echo "[Phase 2/4] Unit tests: FAILED"
    EXIT_CODE=1
fi
echo ""

# --------------------------------------------
# Phase 3: Launch Game for E2E
# --------------------------------------------
echo "[Phase 3/4] Launching game for E2E tests..."
"${GODOT}" --path "${PROJECT_DIR}" &
GODOT_PID=$!

# Wait for game to start
echo "  Waiting for game to initialize..."
MAX_RETRIES=30
RETRY=0
while ! ${DEVTOOLS} ping > /dev/null 2>&1; do
    RETRY=$((RETRY + 1))
    if [ "${RETRY}" -ge "${MAX_RETRIES}" ]; then
        echo "  ERROR: Game failed to start after ${MAX_RETRIES} retries"
        kill "${GODOT_PID}" 2>/dev/null || true
        exit 1
    fi
    sleep 1
done
echo "  Game is running (PID: ${GODOT_PID})"
echo ""

# --------------------------------------------
# Phase 4: E2E Sequences
# --------------------------------------------
echo "[Phase 4/4] Running E2E sequences..."

E2E_PASS=0
E2E_FAIL=0

for SEQ_FILE in "${PROJECT_DIR}"/test/sequences/*.json; do
    SEQ_NAME="$(basename "${SEQ_FILE}")"
    echo "  Running: ${SEQ_NAME}..."
    if ${DEVTOOLS} input sequence "${SEQ_FILE}" 2>&1; then
        echo "  ${SEQ_NAME}: PASSED"
        E2E_PASS=$((E2E_PASS + 1))
    else
        echo "  ${SEQ_NAME}: FAILED"
        E2E_FAIL=$((E2E_FAIL + 1))
        EXIT_CODE=1
    fi
done

echo ""
echo "  E2E Results: ${E2E_PASS} passed, ${E2E_FAIL} failed"

# Run validate-all as final check
echo ""
echo "  Running validate-all..."
if ${DEVTOOLS} validate-all 2>&1; then
    echo "  validate-all: PASSED"
else
    echo "  validate-all: FAILED"
    EXIT_CODE=1
fi

# Run performance check
echo ""
echo "  Running performance check..."
${DEVTOOLS} performance 2>&1 || true

# --------------------------------------------
# Shutdown
# --------------------------------------------
echo ""
echo "Shutting down game..."
${DEVTOOLS} quit 2>/dev/null || true
sleep 2
kill "${GODOT_PID}" 2>/dev/null || true

echo ""
echo "============================================"
if [ "${EXIT_CODE}" -eq 0 ]; then
    echo "  ALL CI CHECKS PASSED"
else
    echo "  SOME CI CHECKS FAILED"
fi
echo "============================================"

exit "${EXIT_CODE}"

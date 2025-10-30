#!/bin/bash
# Aggregates all test cases in tests/cases and runs them sequentially.
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CASES_DIR="${ROOT_DIR}/tests/cases"

if [ ! -d "${CASES_DIR}" ]; then
  echo "No test cases directory found at ${CASES_DIR}" >&2
  exit 1
fi

shopt -s nullglob
cases=("${CASES_DIR}"/*.sh)
shopt -u nullglob

if [ ${#cases[@]} -eq 0 ]; then
  echo "No test cases to run." >&2
  exit 1
fi

for case_script in $(printf '%s\n' "${cases[@]}" | sort); do
  echo "--> Running $(basename "${case_script}")"
  sudo bash "${case_script}"
  echo "<-- Completed $(basename "${case_script}")"
done

echo "✅ All tests passed!"

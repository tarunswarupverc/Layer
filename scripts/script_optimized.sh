#!/usr/bin/env bash
# HiddenLayer Case Study: Automated Model Ingestion & Security Test Pipeline
# Orchestrates end-to-end model retrieval, Git workflow, and CI/CD security gate validation via CLI.

set -euo pipefail

# --- Overridable Configuration Defaults ---
MODEL_URL="${MODEL_URL:-https://huggingface.co/ScanMe/test-models/resolve/main/eval.pkl}"
MODEL_PATH="${MODEL_PATH:-models/eval.pkl}"
BRANCH_NAME="${BRANCH_NAME:-feature/add-hf-model}"
BASE_BRANCH="${BASE_BRANCH:-main}"

# --- Pre-flight Dependency Check ---
need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: Required tool '$1' is not installed or not in PATH." >&2
    exit 1
  }
}

need curl
need git
need gh
need file

# Always execute relative to the git repository root
repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

echo "=== Step 1: Downloading model artifact from registry ==="
mkdir -p "$(dirname "$MODEL_PATH")"
curl -fsSL --output "$MODEL_PATH" "$MODEL_URL"

# Guardrail 1: Detect HTML web page error responses saved as binary
if file "$MODEL_PATH" | grep -qiE 'HTML|ASCII text|Unicode text, UTF-8 text'; then
  echo "Error: Downloaded artifact appears to be an HTML page, not a pickle binary. First 200 bytes:" >&2
  head -c 200 "$MODEL_PATH" >&2
  echo >&2
  exit 1
fi

# Guardrail 2: Validate Python Pickle Magic Byte (0x80)
first_byte="$(xxd -p -l 1 "$MODEL_PATH" 2>/dev/null || od -An -tx1 -N 1 "$MODEL_PATH" | tr -d ' \n')"
if [[ "$first_byte" != 80 ]]; then
  echo "Error: File header missing pickle protocol magic byte 0x80 (got ${first_byte})." >&2
  exit 1
fi

echo "Successfully verified model artifact: $MODEL_PATH ($(wc -c < "$MODEL_PATH" | tr -d ' ') bytes)."

echo "=== Step 2: Managing Git branch, staging, and remote sync ==="
git fetch origin
git checkout "$BASE_BRANCH"
git pull --ff-only origin "$BASE_BRANCH"

if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
  git checkout "$BRANCH_NAME"
else
  git checkout -b "$BRANCH_NAME"
fi

git add "$MODEL_PATH"
if git diff --cached --quiet; then
  echo "No new model changes detected on branch."
else
  git commit -m "feat(security): add HuggingFace model eval.pkl for CI/CD security gate testing"
fi

git push -u origin "$BRANCH_NAME"

echo "=== Step 3: Submitting PR and monitoring CI/CD security gate ==="
if pr_url="$(gh pr view "$BRANCH_NAME" --json url --jq .url 2>/dev/null)"; then
  echo "Active Pull Request detected: $pr_url"
else
  pr_url="$(
    gh pr create \
      --title "Security Audit: Scan HuggingFace eval.pkl" \
      --body "Automated CLI ingestion pipeline testing PickleScan security gate." \
      --base "$BASE_BRANCH" \
      --head "$BRANCH_NAME"
  )"
  echo "Opened Pull Request: $pr_url"
fi

echo "Polling GitHub API for PickleScan workflow execution..."
run_id=""
for _ in {1..20}; do
  run_id="$(gh run list --branch "$BRANCH_NAME" --workflow "PickleScan Security Gate" --limit 1 --json databaseId --jq '.[0].databaseId // empty')"
  if [[ -n "$run_id" ]]; then
    break
  fi
  sleep 3
done

if [[ -z "$run_id" ]]; then
  echo "Warning: Workflow run timed out waiting to start. Track status at: $pr_url"
  exit 0
fi

echo "Streaming logs for Run ID: $run_id..."
gh run watch "$run_id" --exit-status || true

echo "----- SECURITY GATE AUDIT LOGS -----"
gh run view "$run_id" --log-failed || true

echo "Run URL: $(gh run view "$run_id" --json url --jq .url)"
echo "PR URL: $pr_url"
echo "=== Ingestion Pipeline Execution Complete ==="
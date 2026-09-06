#!/usr/bin/env bash
# First extra-credit script: download the HF sample, open a PR, trigger the gate.
# Intentionally naive (no download checks). See script_optimized.sh for the hardened version.
set -e

# Configuration Variables
MODEL_URL="https://huggingface.co/ScanMe/Models/resolve/main/eval.pkl"
BRANCH_NAME="feature/add-hf-model"
BASE_BRANCH="main"

cd "$(git rev-parse --show-toplevel)"

echo "=== 1. Downloading Model from Hugging Face ==="
mkdir -p models
curl -L -o models/eval.pkl "$MODEL_URL"

echo "=== 2. Creating Git Branch & Committing Model ==="
git checkout -b "$BRANCH_NAME" 2>/dev/null || git checkout "$BRANCH_NAME"
git add models/eval.pkl scripts/script.sh
if git diff --cached --quiet; then
  echo "Nothing new to commit. Continuing to push and PR."
else
  git commit -m "feat: add HuggingFace model eval.pkl for CI/CD security scanning"
fi

echo "=== 3. Pushing Branch to GitHub ==="
git push -u origin "$BRANCH_NAME"

echo "=== 4. Creating Pull Request via GitHub CLI ==="
if gh pr view "$BRANCH_NAME" >/dev/null 2>&1; then
  echo "Pull request already exists:"
  gh pr view "$BRANCH_NAME" --json url --jq .url
else
  gh pr create \
    --title "Security Audit: Scan HuggingFace eval.pkl" \
    --body "Automated PR created via CLI script to test PickleScan security gate." \
    --base "$BASE_BRANCH" \
    --head "$BRANCH_NAME"
fi

echo "=== Pipeline Triggered Successfully! Check GitHub Actions tab. ==="

#!/usr/bin/env bash
set -e

# Configuration Variables
MODEL_URL="https://huggingface.co/ScanMe/Models/resolve/main/eval.pkl"
BRANCH_NAME="feature/add-hf-model"

echo "=== 1. Downloading Model from Hugging Face ==="
mkdir -p models
curl -L -o models/eval.pkl "$MODEL_URL"

echo "=== 2. Creating Git Branch & Committing Model ==="
git checkout -b "$BRANCH_NAME" 2>/dev/null || git checkout "$BRANCH_NAME"
git add models/eval.pkl
git commit -m "feat: add HuggingFace model eval.pkl for CI/CD security scanning"

echo "=== 3. Pushing Branch to GitHub ==="
git push -u origin "$BRANCH_NAME"

echo "=== 4. Creating Pull Request via GitHub CLI ==="
gh pr create \
  --title "Security Audit: Scan HuggingFace eval.pkl" \
  --body "Automated PR created via CLI script to test PickleScan security gate." \
  --base main \
  --head "$BRANCH_NAME"

echo "=== Pipeline Triggered Successfully! Check GitHub Actions tab. ==="
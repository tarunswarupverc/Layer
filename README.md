# Layer — PickleScan security gate

GitHub Actions scans every pull request to `main` that touches this repo. If PickleScan finds a dangerous pickle (for example `builtins.eval`), the check **fails with exit 1**. That red X is the security gate working, not a broken pipeline.

## Layout

```
models/                              # artifacts scanned on each PR
.github/workflows/picklescan.yml     # simple gate
.github/workflows/picklescan-optimized.yml
scripts/script.sh                    # extra credit: first CLI version
scripts/script_optimized.sh          # extra credit: hardened CLI version
```

## Two workflows (same gate)

Both run on PRs to `main`, install pinned `picklescan==1.0.4`, and scan `models/`.

| Workflow | What it adds |
|---|---|
| **Simple** | Minimum requirement: checkout, Python 3.10, scan, fail on infection |
| **Optimized** | Same scan, plus “does `models/` exist?”, log capture, job summary, current Actions runtimes |

## Two scripts (how this was built)

These are extra credit. They download `eval.pkl` from Hugging Face, open a PR, and trigger the gate. **Keep both.** The simple script is the first version; the optimized script is what we learned after the first PR passed on an HTML download.

```bash
# Naive (from scratch). curl -L can save an HTML error page as eval.pkl.
./scripts/script.sh

# Hardened. Fail closed on HTML, check pickle magic byte 0x80, watch both workflows.
./scripts/script_optimized.sh
```

Needs `git`, `gh` (authenticated), and `curl`. Run from a clone of this repo.

## Expected result

A PR that adds the Hugging Face `eval.pkl` sample should fail:

```
dangerous import 'builtins eval' FOUND
Infected files: 1
```

`eval.pkl` is **not** on `main` on purpose. Merge would put a known-malicious artifact on the default branch, and the gate only runs on pull requests.

## Reproduce without the scripts

```bash
mkdir -p models
curl -fL -o models/eval.pkl \
  https://huggingface.co/ScanMe/Models/resolve/main/eval.pkl
git checkout -b demo/add-eval-pkl
git add models/eval.pkl
git commit -m "Add Hugging Face eval.pkl for PickleScan"
git push -u origin HEAD
gh pr create --base main --title "Security Audit: Scan HuggingFace eval.pkl"
```

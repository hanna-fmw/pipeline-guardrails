#!/bin/bash
# Releases the kit: tags vX.Y.Z on a commit where every kit reference inside .github/ is pinned to vX.Y.Z, so a repo
# running vX.Y.Z runs that version's files throughout, and the canary can try it before any other repo.
# v1, which every repo runs, does not move here: sync.sh moves it once the canary repo passed on this exact
# version (layer review, layer 4). Patch releases happen by themselves (selftest.yml's release job runs this with
# `patch --ci`); a minor or major one is run by hand. Refuses unless main is pushed and selftest passed on it.
# Usage: release.sh vX.Y.Z | patch [--ci]   (a breaking change is a new major: v2.0.0, then repos move one by one)
set -euo pipefail
v=${1:?usage: release.sh vX.Y.Z | patch [--ci]} ci=${2:-}
cd "$(dirname "$0")/.."
git fetch -q --force origin main 'refs/tags/*:refs/tags/*'
sha=$(git rev-parse origin/main)
if [ "$(git rev-parse HEAD)" != "$sha" ]; then
  [ "$ci" = --ci ] && { echo "main moved on: its own run releases it"; exit 0; }
  echo "FAILED: check out origin/main first (HEAD is not it)"; exit 1
fi
last=$(git tag -l 'v*.*.*' --sort=-v:refname | head -1)
# a release commit's parent is the main commit it was made from
[ "$(git rev-parse -q --verify "$last^{commit}^" || true)" != "$sha" ] && [ "$(git rev-parse "$last^{commit}")" != "$sha" ] \
  || { echo "$last is this commit already"; exit 0; }
if [ "$v" = patch ]; then IFS=. read -r M m p <<<"${last#v}"; v="v$M.$m.$((p + 1))"; fi
[[ $v =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "FAILED: version must look like v1.2.0"; exit 1; }
if [ "$ci" != --ci ]; then
  runs=$(gh api "repos/hanna-fmw/pipeline-guardrails/actions/workflows/selftest.yml/runs?head_sha=$sha&event=push" --jq '[.workflow_runs[] | .conclusion]')
  jq -e 'index("success") != null' <<<"$runs" >/dev/null || { echo "FAILED: selftest has not passed on $sha (runs: $runs)"; exit 1; }
fi
git checkout -q --detach "$sha"
find .github -type f -name '*.yml' -print0 | xargs -0 perl -pi -e "s#(hanna-fmw/pipeline-guardrails/\.github/[^@ ]+)\@v1\b#\$1\@$v#g" --
git commit -qam "release $v: kit references pinned to $v"
git tag -a "$v" -m "$v"
git push -q origin "$v"
# The changelog: GitHub's release page, notes written from the commits since the last release
gh release create "$v" -R hanna-fmw/pipeline-guardrails --verify-tag --generate-notes --latest >/dev/null
echo "released $v (v1 moves to it after the canary passes: sync.sh)"

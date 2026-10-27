#!/bin/bash
# Copy 3 of 3-2-1: pulls a project's R2 backup bucket onto an external drive, monthly.
# Adds new files only; never deletes on the drive. Prints no secret values.
# Keys come from the macOS Keychain, account <project>: R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY,
# R2_ENDPOINT, and optionally HC_DRIVE_URL (a Healthchecks check that reminds you monthly).
# Usage: pull-backups-to-drive.sh <project> <bucket> <drive folder> [--check]
set -euo pipefail
project=$1 bucket=$2 dest=$3
key() { security find-generic-password -a "$project" -s "$1" -w; }
AWS_ACCESS_KEY_ID="$(key R2_ACCESS_KEY_ID)"; AWS_SECRET_ACCESS_KEY="$(key R2_SECRET_ACCESS_KEY)"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION=auto
ep="$(key R2_ENDPOINT)"

r2=$(aws s3 ls "s3://$bucket/" --recursive --endpoint-url "$ep" | wc -l | tr -d ' ')
echo "In R2: $r2 files"
[ "${4:-}" = --check ] && exit 0

[ -d "$(dirname "$dest")" ] || { echo "Drive not connected: plug it in, then run again."; exit 1; }
mkdir -p "$dest"
aws s3 sync "s3://$bucket/" "$dest/" --endpoint-url "$ep" --only-show-errors
here=$(find "$dest" -type f ! -name last-copy.txt | wc -l | tr -d ' ')
echo "On the drive: $here files"
[ "$here" -ge "$r2" ] || { echo "The drive has fewer files than R2: run again."; exit 1; }
date '+%Y-%m-%d %H:%M' > "$dest/last-copy.txt"
hc="$(key HC_DRIVE_URL 2>/dev/null || true)"
[ -z "$hc" ] || curl -fsS -m 10 --retry 3 -o /dev/null "$hc" || true
echo "Done."

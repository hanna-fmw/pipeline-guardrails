#!/bin/bash
# Copy 3 of 3-2-1: pulls a project's R2 backup bucket onto an external drive, monthly.
# Adds new files only; never deletes on the drive. Prints no secret values.
# Keys come from Infisical (the project's /backup folder): R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ENDPOINT.
# Usage: pull-backups-to-drive.sh <infisical project id> <env> <bucket> <drive folder> [--check]
set -euo pipefail
pid=$1 env=$2 bucket=$3 dest=$4
key() { infisical secrets get "$1" --projectId "$pid" --env "$env" --path /backup --plain --silent | tr -d '\n'; }
AWS_ACCESS_KEY_ID="$(key R2_ACCESS_KEY_ID)"; AWS_SECRET_ACCESS_KEY="$(key R2_SECRET_ACCESS_KEY)"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION=auto
ep="$(key R2_ENDPOINT)"

r2=$(aws s3 ls "s3://$bucket/" --recursive --endpoint-url "$ep" | wc -l | tr -d ' ')
echo "In R2: $r2 files"
[ "${5:-}" = --check ] && exit 0

[ -d "$(dirname "$dest")" ] || { echo "Drive not connected: plug it in, then run again."; exit 1; }
mkdir -p "$dest"
aws s3 sync "s3://$bucket/" "$dest/" --endpoint-url "$ep" --only-show-errors
here=$(find "$dest" -type f ! -name last-copy.txt | wc -l | tr -d ' ')
echo "On the drive: $here files"
[ "$here" -ge "$r2" ] || { echo "The drive has fewer files than R2: run again."; exit 1; }
date '+%Y-%m-%d %H:%M' > "$dest/last-copy.txt"
echo "Done."

#!/bin/sh
set -eu

target=${1:-}
script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(dirname "$script_directory")
backup_directory="$repository_root/Server/backups"
timestamp=$(date -u +"%Y%m%dT%H%M%SZ")

case "$target" in
  staging)
    database=tali-staging
    environment_args="--env staging"
    ;;
  production)
    database=tali
    environment_args=""
    ;;
  *)
    echo "Usage: $0 staging|production"
    exit 2
    ;;
esac

mkdir -p "$backup_directory"
output="$backup_directory/${target}-${timestamp}.sql"
cd "$repository_root/Server"
# shellcheck disable=SC2086
npx wrangler d1 export "$database" --remote --output "$output" $environment_args
test -s "$output"
echo "Encrypted storage is recommended. Backup created at $output"

#!/bin/sh
set -eu

target=${1:-}
script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
server_directory="$(dirname "$script_directory")/Server"

case "$target" in
  staging)
    database=tali-staging
    environment_args="--env staging"
    ;;
  production)
    if [ "${TALI_CONFIRM_PRODUCTION:-}" != "deploy-production" ]; then
      echo "Production deploy refused."
      echo "Re-run with TALI_CONFIRM_PRODUCTION=deploy-production after reviewing the diff and backup."
      exit 2
    fi
    database=tali
    environment_args=""
    ;;
  *)
    echo "Usage: $0 staging|production"
    exit 2
    ;;
esac

cd "$server_directory"
npm ci
npm run check
npm test -- --run

echo "Applying migrations to $target database: $database"
# shellcheck disable=SC2086
npx wrangler d1 migrations apply "$database" --remote $environment_args

echo "Deploying Worker to $target"
# shellcheck disable=SC2086
npx wrangler deploy $environment_args

#!/usr/bin/env bash
# Uploads adscian/public/ to Combell shared hosting via FTP/FTPS.
# Credentials come from adscian/.env.deploy (gitignored) — see
# adscian/.env.deploy.example for the template. Never commit real
# credentials, and never echo them to output.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ADSCIAN_DIR="$REPO_ROOT/adscian"
ENV_FILE="$ADSCIAN_DIR/.env.deploy"
PUBLIC_DIR="$ADSCIAN_DIR/public"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE." >&2
  echo "Copy adscian/.env.deploy.example to adscian/.env.deploy and fill in your Combell FTP details." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${FTP_HOST:?FTP_HOST not set in .env.deploy}"
: "${FTP_USER:?FTP_USER not set in .env.deploy}"
: "${FTP_PASSWORD:?FTP_PASSWORD not set in .env.deploy}"
FTP_REMOTE_DIR="${FTP_REMOTE_DIR:-/}"
FTP_PROTOCOL="${FTP_PROTOCOL:-ftpes}"

case "$FTP_PROTOCOL" in
  ftp)   SCHEME="ftp";  SSL_OPTS=() ;;
  ftpes) SCHEME="ftp";  SSL_OPTS=(--ssl-reqd) ;;
  ftps)  SCHEME="ftps"; SSL_OPTS=() ;;
  *)
    echo "Unknown FTP_PROTOCOL: $FTP_PROTOCOL (use ftp, ftpes, or ftps)" >&2
    exit 1
    ;;
esac

if [ ! -d "$PUBLIC_DIR" ]; then
  echo "Build output not found at $PUBLIC_DIR — run npm run build first." >&2
  exit 1
fi

REMOTE_BASE="/${FTP_REMOTE_DIR#/}"
REMOTE_BASE="${REMOTE_BASE%/}"

cd "$PUBLIC_DIR"
mapfile -t FILES < <(find . -type f | sed 's|^\./||')
TOTAL="${#FILES[@]}"

if [ "$TOTAL" -eq 0 ]; then
  echo "No files found under $PUBLIC_DIR — nothing to upload." >&2
  exit 1
fi

echo "Uploading $TOTAL files from public/ to ${SCHEME}://${FTP_HOST}${REMOTE_BASE}/ ..."

count=0
failed=0
for f in "${FILES[@]}"; do
  count=$((count + 1))
  remote_path="${REMOTE_BASE}/${f}"
  printf "[%d/%d] %s\n" "$count" "$TOTAL" "$f"
  if ! curl -sS --ftp-create-dirs "${SSL_OPTS[@]}" \
      --user "${FTP_USER}:${FTP_PASSWORD}" \
      -T "$f" \
      "${SCHEME}://${FTP_HOST}${remote_path}"; then
    echo "  FAILED: $f" >&2
    failed=$((failed + 1))
  fi
done

echo ""
echo "Done. Uploaded $((TOTAL - failed))/$TOTAL files."
if [ "$failed" -gt 0 ]; then
  echo "$failed file(s) failed to upload — see FAILED lines above." >&2
  exit 1
fi
echo "Note: this only adds/overwrites files — it never deletes remote files no longer present locally."

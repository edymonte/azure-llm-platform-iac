#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run_with_backend_access.sh
#
# Backend storage access policy:
#   • Storage is CREATED OPEN by Terraform (backend-storage/main.tf).
#   • Stays open during init / plan / apply of the main project.
#   • CLOSED automatically only after a successful apply (EXIT trap).
#   • Manual open-access / close-access commands exist for recovery only.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

readonly PRIMARY_RG="rg-azllm-tfstate-dev"
readonly PRIMARY_SA="stazllmtfdev"
readonly BACKEND_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# ─── Helpers ─────────────────────────────────────────────────────────────────

usage() {
  cat <<'USAGE'
Usage: ./run_with_backend_access.sh <command> [args]

Commands:
  open-access     Manually re-open backend storage (recovery)
  close-access    Manually close backend storage (emergency)
  init  [args]    terraform init  — storage must be open
  plan  [args]    terraform plan  — storage must be open
  apply [args]    terraform apply — auto-closes storage after success
  destroy [args]  terraform destroy
USAGE
  exit 1
}

[[ $# -eq 0 ]] && usage
TF_CMD="$1"; shift

# ─── Storage control ─────────────────────────────────────────────────────────

open_backend_storage() {
  echo "==> Opening backend storage access..."
  az storage account update \
    --resource-group "$PRIMARY_RG" \
    --name "$PRIMARY_SA" \
    --public-network-access Enabled \
    --default-action Allow \
    --output none
  echo "    Open."
}

close_backend_storage() {
  echo "==> Closing backend storage access..."
  az storage account update \
    --resource-group "$PRIMARY_RG" \
    --name "$PRIMARY_SA" \
    --public-network-access Disabled \
    --default-action Deny \
    --output none 2>/dev/null || {
      echo "    WARNING: Could not close storage — check manually."
      return 0
    }
  echo "    Closed."
}

wait_backend_accessible() {
  echo "==> Checking backend storage accessibility..."
  local i state
  for i in $(seq 1 10); do
    state="$(az storage account show \
      --resource-group "$PRIMARY_RG" \
      --name "$PRIMARY_SA" \
      --query "{pub:publicNetworkAccess,act:networkRuleSet.defaultAction}" \
      --output json 2>/dev/null || echo '{}')"
    if echo "$state" | grep -q '"pub": "Enabled"' && echo "$state" | grep -q '"act": "Allow"'; then
      echo "    Backend accessible."
      return 0
    fi
    echo "    Attempt $i/10 — waiting 5s..."
    sleep 5
  done
  echo "ERROR: Backend storage not accessible after 50s. Run open-access manually."
  exit 1
}

# ─── Commands ────────────────────────────────────────────────────────────────

case "$TF_CMD" in
  open-access)
    open_backend_storage
    ;;
  close-access)
    close_backend_storage
    ;;
  init)
    wait_backend_accessible
    cd "$BACKEND_DIR"
    terraform init "$@"
    ;;
  plan)
    wait_backend_accessible
    cd "$BACKEND_DIR"
    terraform plan "$@"
    ;;
  apply)
    wait_backend_accessible
    cd "$BACKEND_DIR"
    trap 'close_backend_storage' EXIT
    terraform apply "$@"
    ;;
  destroy)
    wait_backend_accessible
    cd "$BACKEND_DIR"
    trap 'close_backend_storage' EXIT
    terraform destroy "$@"
    ;;
  *)
    echo "Unknown command: $TF_CMD"
    usage
    ;;
esac

# ────────────────────────────────────────────────────────────────────────────────
# TERRAFORM BACKEND
# Fill backend.tfvars with values from the backend-storage stage output
#
# Init:
#   terraform init -backend-config=backend.tfvars
# ────────────────────────────────────────────────────────────────────────────────

terraform {
  backend "azurerm" {
    # Values supplied via backend.tfvars
  }
}

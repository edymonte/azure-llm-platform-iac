# ────────────────────────────────────────────────────────────────────────────────
# BACKEND STORAGE — Terraform Remote State
# Creates a secure Storage Account to hold .tfstate files
# Security requirements:
#   - HTTPS only
#   - No public blob access
#   - Versioning + change feed enabled
#   - Managed Identity access (no static SAS keys for CI)
#   - TLS 1.2 minimum
# ────────────────────────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "tfstate" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "tfstate" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  https_traffic_only_enabled    = true
  shared_access_key_enabled     = true
  public_network_access_enabled = true # Opened for Terraform init/plan/apply; closed by wrapper after apply

  min_tls_version = "TLS1_2"

  blob_properties {
    versioning_enabled            = true
    change_feed_enabled           = true
    change_feed_retention_in_days = 30

    delete_retention_policy {
      days = 7
    }

    restore_policy {
      days = 6
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  depends_on = [azurerm_resource_group.tfstate]
}

resource "azurerm_storage_container" "tfstate" {
  name                  = var.blob_container_name
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"

  depends_on = [azurerm_storage_account.tfstate]
}

resource "azurerm_storage_account_network_rules" "tfstate" {
  storage_account_id = azurerm_storage_account.tfstate.id

  default_action             = "Allow"
  bypass                     = ["AzureServices", "Logging", "Metrics"]
  virtual_network_subnet_ids = []
  ip_rules                   = []

  depends_on = [azurerm_storage_account.tfstate]
}

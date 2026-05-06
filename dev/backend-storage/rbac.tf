data "azurerm_client_config" "current" {}

# Storage Blob Data Contributor — allows Terraform to read/write state via AAD
resource "azurerm_role_assignment" "tfstate_blob_contributor" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Managed Identity for CI/CD pipelines
resource "azurerm_user_assigned_identity" "tfstate" {
  name                = "id-${var.project_name}-tfstate-${var.environment}"
  resource_group_name = azurerm_resource_group.tfstate.name
  location            = azurerm_resource_group.tfstate.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "tfstate_mi_blob_contributor" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.tfstate.principal_id
}

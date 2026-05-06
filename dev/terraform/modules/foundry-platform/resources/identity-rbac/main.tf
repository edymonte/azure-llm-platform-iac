variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "naming_prefix" { type = string }
variable "tags" { type = map(string) }

data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "foundry" {
  name                = "id-${var.naming_prefix}-foundry"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "cognitive_services_user" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_user_assigned_identity.foundry.principal_id
}

output "managed_identity_id" { value = azurerm_user_assigned_identity.foundry.id }
output "managed_identity_principal_id" { value = azurerm_user_assigned_identity.foundry.principal_id }
output "managed_identity_client_id" { value = azurerm_user_assigned_identity.foundry.client_id }

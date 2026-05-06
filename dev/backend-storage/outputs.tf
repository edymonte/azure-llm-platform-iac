output "storage_account_name" {
  description = "Storage Account name — use in backend.tfvars"
  value       = azurerm_storage_account.tfstate.name
}

output "resource_group_name" {
  description = "Resource Group name — use in backend.tfvars"
  value       = azurerm_resource_group.tfstate.name
}

output "blob_container_name" {
  description = "Blob container name — use in backend.tfvars"
  value       = azurerm_storage_container.tfstate.name
}

output "managed_identity_id" {
  description = "Managed Identity resource ID — use in CI/CD"
  value       = azurerm_user_assigned_identity.tfstate.id
}

output "managed_identity_client_id" {
  description = "Managed Identity client ID — use in federated credentials"
  value       = azurerm_user_assigned_identity.tfstate.client_id
}

output "terraform_backend_config" {
  description = "Ready-to-paste backend.tfvars snippet"
  value       = <<-EOT
    resource_group_name  = "${azurerm_resource_group.tfstate.name}"
    storage_account_name = "${azurerm_storage_account.tfstate.name}"
    container_name       = "${azurerm_storage_container.tfstate.name}"
    key                  = "azllm/foundry/terraform.tfstate"
    use_azuread_auth     = true
  EOT
}

output "resource_group_id" {
  description = "Resource Group ID"
  value       = module.foundry_platform.resource_group_id
}

output "resource_group_name" {
  description = "Resource Group name"
  value       = module.foundry_platform.resource_group_name
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = module.foundry_platform.vnet_id
}

output "vnet_name" {
  description = "Virtual Network name"
  value       = module.foundry_platform.vnet_name
}

output "foundry_resources" {
  description = "Foundry resources created per region"
  value       = module.foundry_platform.foundry_resources
}

output "key_vault_id" {
  description = "Key Vault ID"
  value       = module.foundry_platform.key_vault_id
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.foundry_platform.key_vault_uri
}

output "managed_identity_id" {
  description = "Managed Identity resource ID"
  value       = module.foundry_platform.managed_identity_id
}

output "managed_identity_principal_id" {
  description = "Managed Identity principal ID"
  value       = module.foundry_platform.managed_identity_principal_id
}

output "managed_identity_client_id" {
  description = "Managed Identity client ID"
  value       = module.foundry_platform.managed_identity_client_id
}

output "ai_services_details" {
  description = "AI Services endpoints and configuration"
  value       = module.foundry_platform.ai_services_details
}

output "litellm_accounts" {
  description = "Endpoints and keys per region for LiteLLM routing"
  value       = module.foundry_platform.litellm_accounts
  sensitive   = true
}

output "container_app_environment_id" {
  value = module.foundry_platform.container_app_environment_id
}

output "container_app_ids" {
  value = module.foundry_platform.container_app_ids
}

output "container_app_names" {
  value = module.foundry_platform.container_app_names
}

output "container_app_latest_revision_fqdns" {
  value = module.foundry_platform.container_app_latest_revision_fqdns
}

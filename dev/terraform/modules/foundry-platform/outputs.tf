output "resource_group_id" {
  value = module.resource_group.id
}

output "resource_group_name" {
  value = module.resource_group.name
}

output "vnet_id" {
  value = module.networking.vnet_id
}

output "vnet_name" {
  value = module.networking.vnet_name
}

output "subnets" {
  value = {
    workload         = module.networking.workload_subnet_id
    private_endpoint = module.networking.private_endpoint_subnet_id
    ai_services      = module.networking.ai_services_subnet_id
  }
}

output "managed_identity_id" {
  value = module.identity_rbac.managed_identity_id
}

output "managed_identity_principal_id" {
  value = module.identity_rbac.managed_identity_principal_id
}

output "managed_identity_client_id" {
  value = module.identity_rbac.managed_identity_client_id
}

output "key_vault_id" {
  value = module.foundry_ai.key_vault_id
}

output "key_vault_uri" {
  value = module.foundry_ai.key_vault_uri
}

output "foundry_resources" {
  value = module.foundry_ai.foundry_resources
}

output "ai_services_details" {
  value = module.foundry_ai.ai_services_details
}

output "litellm_accounts" {
  value     = module.foundry_ai.litellm_accounts
  sensitive = true
}

output "container_app_environment_id" {
  value = var.container_apps_config.enabled ? module.container_apps[0].container_app_environment_id : null
}

output "container_app_id" {
  value = var.container_apps_config.enabled ? module.container_apps[0].container_app_id : null
}

output "container_app_name" {
  value = var.container_apps_config.enabled ? module.container_apps[0].container_app_name : null
}

output "container_app_ids" {
  value = var.container_apps_config.enabled ? module.container_apps[0].container_app_ids : null
}

output "container_app_names" {
  value = var.container_apps_config.enabled ? module.container_apps[0].container_app_names : null
}

output "container_app_latest_revision_fqdn" {
  value = var.container_apps_config.enabled ? module.container_apps[0].container_app_latest_revision_fqdn : null
}

output "container_app_latest_revision_fqdns" {
  value = var.container_apps_config.enabled ? module.container_apps[0].container_app_latest_revision_fqdns : null
}

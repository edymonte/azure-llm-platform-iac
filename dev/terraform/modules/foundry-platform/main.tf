# ────────────────────────────────────────────────────────────────────────────────
# FOUNDRY PLATFORM — MAIN MODULE
# Sub-module orchestration
# ────────────────────────────────────────────────────────────────────────────────

module "resource_group" {
  source = "./resources/resource-group"

  resource_group_name = var.resource_group_name
  location            = var.primary_location
  tags                = local.common_tags
}

module "networking" {
  source = "./resources/networking"

  resource_group_name = module.resource_group.name
  location            = var.primary_location

  vnet_name          = local.network_config.vnet_name
  vnet_address_space = var.vnet_address_space

  workload_subnet = {
    name           = local.network_config.workload_subnet_name
    address_prefix = var.workload_subnet_prefix
  }

  private_endpoint_subnet = {
    name           = local.network_config.private_endpoint_subnet_name
    address_prefix = var.private_endpoint_subnet_prefix
  }

  ai_services_subnet = {
    name           = local.network_config.ai_services_subnet_name
    address_prefix = var.ai_services_subnet_prefix
  }

  container_apps_subnet = {
    name           = local.network_config.container_apps_subnet_name
    address_prefix = var.container_apps_subnet_prefix
  }

  tags = local.common_tags
}

module "identity_rbac" {
  source = "./resources/identity-rbac"

  resource_group_name = module.resource_group.name
  location            = var.primary_location
  naming_prefix       = "${var.project_name}-${var.environment}"

  tags = local.common_tags
}

module "foundry_ai" {
  source = "./resources/foundry-ai"

  resource_group_name   = module.resource_group.name
  regions               = local.enabled_regions
  foundry_models_config = var.foundry_models_config

  vnet_id               = module.networking.vnet_id
  ai_services_subnet_id = module.networking.ai_services_subnet_id

  managed_identity_id = module.identity_rbac.managed_identity_id

  quota_limits = var.quota_limits

  key_vault_name = var.key_vault_name
  key_vault_sku  = var.key_vault_sku

  naming_prefix      = "${var.project_name}-${var.environment}"
  prisma_cloud_cidrs = var.prisma_cloud_cidrs

  resolve_latest_model_version      = var.resolve_latest_model_version
  enable_soft_deleted_account_purge = var.enable_soft_deleted_account_purge

  tags = local.common_tags

  depends_on = [
    module.resource_group,
    module.networking,
    module.identity_rbac
  ]
}

module "container_apps" {
  count  = var.container_apps_config.enabled ? 1 : 0
  source = "./resources/litellm-proxy"

  resource_group_name      = module.resource_group.name
  location                 = var.primary_location
  container_apps_subnet_id = module.networking.container_apps_subnet_id

  managed_identity_id           = module.identity_rbac.managed_identity_id
  managed_identity_principal_id = module.identity_rbac.managed_identity_principal_id
  managed_identity_client_id    = module.identity_rbac.managed_identity_client_id

  container_apps_environment_name = var.container_apps_config.container_env_name
  foundry_accounts                = module.foundry_ai.litellm_accounts
  foundry_resource_ids            = module.foundry_ai.foundry_resource_ids

  acr_login_server = var.container_apps_config.acr_login_server
  acr_resource_id  = var.container_apps_config.acr_resource_id

  litellm_tpm_limits = var.litellm_tpm_limits

  enable_cae_internal_only = var.enable_cae_internal_only
  enable_external_ingress  = var.enable_litellm_external_ingress

  llm_app  = var.container_apps_config.llm_app
  test_app = var.container_apps_config.test_app
  val_app  = var.container_apps_config.val_app

  tags = local.common_tags

  depends_on = [
    module.resource_group,
    module.networking,
    module.identity_rbac,
    module.foundry_ai
  ]
}

# ────────────────────────────────────────────────────────────────────────────────
# AZURE LLM PLATFORM — MAIN
# Orchestrates the foundry-platform module
# ────────────────────────────────────────────────────────────────────────────────

module "foundry_platform" {
  source = "./modules/foundry-platform"

  # Basic
  project_name        = var.project_name
  environment         = var.environment
  primary_location    = var.primary_location
  resource_group_name = var.resource_group_name

  # Regions
  regions = var.regions

  # Model
  foundry_models_config = var.foundry_models_config

  # Network
  vnet_address_space             = var.vnet_address_space
  workload_subnet_prefix         = var.workload_subnet_prefix
  private_endpoint_subnet_prefix = var.private_endpoint_subnet_prefix
  ai_services_subnet_prefix      = var.ai_services_subnet_prefix
  container_apps_subnet_prefix   = var.container_apps_subnet_prefix

  # Network access
  enable_cae_internal_only        = var.enable_cae_internal_only
  allowed_test_cidrs              = var.allowed_test_cidrs
  enable_litellm_external_ingress = var.enable_litellm_external_ingress
  prisma_cloud_cidrs              = var.prisma_cloud_cidrs

  # Quota
  quota_limits = var.quota_limits

  # Key Vault
  key_vault_name = var.key_vault_name
  key_vault_sku  = var.key_vault_sku

  # Container Apps
  container_apps_config = var.container_apps_config

  # LiteLLM TPM limits
  litellm_tpm_limits = var.litellm_tpm_limits

  # Compatibility flags
  resolve_latest_model_version      = var.resolve_latest_model_version
  enable_soft_deleted_account_purge = var.enable_soft_deleted_account_purge

  # Tags
  tags = merge(
    var.tags,
    {
      environment = var.environment
      project     = var.project_name
      managed_by  = "terraform"
    }
  )
}

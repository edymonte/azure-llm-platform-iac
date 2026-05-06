# ────────────────────────────────────────────────────────────────────────────────
# FOUNDRY PLATFORM — LOCALS
# ────────────────────────────────────────────────────────────────────────────────

locals {
  naming_prefix = "${var.project_name}-${var.environment}"

  enabled_regions = {
    for region, config in var.regions :
    region => config if config.enabled
  }

  model_config = {
    deployment_name = var.foundry_models_config.deployment_name
    model_name      = var.foundry_models_config.model_name
    model_format    = var.foundry_models_config.model_format
    model_version   = var.foundry_models_config.model_version
    sku_name        = var.foundry_models_config.sku_name
    capacity        = var.foundry_models_config.capacity
  }

  common_tags = merge(
    var.tags,
    {
      managed_by = "terraform"
      module     = "foundry-platform"
    }
  )

  network_config = {
    vnet_name                    = "vnet-${local.naming_prefix}"
    workload_subnet_name         = "snet-${local.naming_prefix}-workload"
    private_endpoint_subnet_name = "snet-${local.naming_prefix}-pep"
    ai_services_subnet_name      = "snet-${local.naming_prefix}-ai"
    container_apps_subnet_name   = "snet-${local.naming_prefix}-aca"
  }

  security_config = {
    enable_network_policies  = true
    enable_private_endpoints = true
    enable_service_endpoints = true
    min_tls_version          = "TLS1_2"
  }

  foundry_by_region = {
    for region, config in local.enabled_regions : region => {
      location      = config.location
      location_code = config.location_code
      resource_names = {
        ai_hub  = "hub-${local.naming_prefix}-${config.location_code}"
        project = "proj-${local.naming_prefix}-${config.location_code}"
      }
    }
  }
}

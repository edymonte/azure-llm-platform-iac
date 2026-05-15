terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
  }
}

variable "resource_group_name" { type = string }
variable "regions" {
  type = map(object({
    location      = string
    location_code = string
    enabled       = bool
  }))
}
variable "foundry_models_config" {
  type = object({
    deployment_name = string
    model_name      = string
    model_format    = string
    model_version   = string
    sku_name        = string
    capacity        = number
  })
}
variable "vnet_id" { type = string }
variable "ai_services_subnet_id" { type = string }
variable "managed_identity_id" { type = string }
variable "quota_limits" {
  type = object({
    gpt_4o_quota = number
  })
}
variable "key_vault_name" { type = string }
variable "key_vault_sku" { type = string }
variable "naming_prefix" { type = string }
variable "tags" { type = map(string) }
variable "enable_soft_deleted_account_purge" {
  type    = bool
  default = true
}

variable "resolve_latest_model_version" {
  type    = bool
  default = true
}

variable "prisma_cloud_cidrs" {
  type    = list(string)
  default = []
}

variable "enable_public_network_access" {
  type    = bool
  default = true
}

data "azurerm_client_config" "current" {}
data "azurerm_resource_group" "main" { name = var.resource_group_name }

locals {
  foundry_targets = {
    for region_key, region in var.regions : region_key => {
      name             = "aif-${replace(var.naming_prefix, "-", "")}-${region.location_code}-01"
      location         = region.location
      code             = region.location_code
      custom_subdomain = "api-${replace(var.naming_prefix, "-", "")}-${region.location_code}-01"
    } if region.enabled
  }
}

resource "azurerm_storage_account" "foundry" {
  name                          = "st${replace(var.naming_prefix, "-", "")}fnd01"
  location                      = data.azurerm_resource_group.main.location
  resource_group_name           = var.resource_group_name
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  https_traffic_only_enabled    = true
  public_network_access_enabled = var.enable_public_network_access

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = var.prisma_cloud_cidrs
  }

  tags = var.tags
}

resource "azurerm_key_vault" "foundry" {
  name                       = var.key_vault_name
  location                   = data.azurerm_resource_group.main.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = var.key_vault_sku
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  enable_rbac_authorization  = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

resource "azapi_resource" "foundry" {
  for_each = local.foundry_targets

  type      = "Microsoft.CognitiveServices/accounts@2024-10-01"
  name      = each.value.name
  location  = each.value.location
  parent_id = data.azurerm_resource_group.main.id

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    properties = {
      customSubDomainName = each.value.custom_subdomain
      publicNetworkAccess = var.enable_public_network_access ? "Enabled" : "Disabled"
      networkAcls = {
        defaultAction = "Deny"
        bypass        = "AzureServices"
        ipRules       = [for cidr in var.prisma_cloud_cidrs : { value = cidr }]
      }
    }
  }

  tags                      = merge(var.tags, { foundry_region = each.value.code })
  schema_validation_enabled = false
}

resource "azapi_resource" "global_standard" {
  for_each = local.foundry_targets

  type      = "Microsoft.CognitiveServices/accounts/deployments@2025-12-01"
  name      = var.foundry_models_config.deployment_name
  parent_id = azapi_resource.foundry[each.key].id

  body = {
    sku = {
      name     = var.foundry_models_config.sku_name
      capacity = var.foundry_models_config.capacity
    }
    properties = {
      model = {
        format  = var.foundry_models_config.model_format
        name    = var.foundry_models_config.model_name
        version = var.foundry_models_config.model_version
      }
      raiPolicyName = "Microsoft.Default"
    }
  }

  schema_validation_enabled = false
}

output "key_vault_id" { value = azurerm_key_vault.foundry.id }
output "key_vault_uri" { value = azurerm_key_vault.foundry.vault_uri }
output "foundry_resource_ids" { value = { for k, v in azapi_resource.foundry : k => v.id } }
output "foundry_resources" {
  value = {
    for k, v in local.foundry_targets : k => {
      name     = v.name
      location = v.location
      id       = azapi_resource.foundry[k].id
    }
  }
}
output "ai_services_details" {
  value = {
    for k, v in local.foundry_targets : k => {
      account_name = v.name
      endpoint     = "https://${v.custom_subdomain}.cognitiveservices.azure.com/"
      model        = var.foundry_models_config.model_name
      deployment   = var.foundry_models_config.deployment_name
    }
  }
}
output "litellm_accounts" {
  sensitive = true
  value = {
    for k, v in local.foundry_targets : k => {
      account_name  = v.name
      endpoint      = "https://${v.custom_subdomain}.cognitiveservices.azure.com/"
      deployment    = var.foundry_models_config.deployment_name
      api_key       = "set-via-key-vault"
      model_name    = var.foundry_models_config.model_name
      location_code = v.code
    }
  }
}

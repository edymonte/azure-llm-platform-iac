variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "container_apps_subnet_id" { type = string }
variable "managed_identity_id" { type = string }
variable "managed_identity_principal_id" { type = string }
variable "managed_identity_client_id" { type = string }
variable "container_apps_environment_name" { type = string }
variable "foundry_accounts" { type = any }
variable "foundry_resource_ids" { type = any }
variable "acr_login_server" { type = string }
variable "acr_resource_id" { type = string }
variable "litellm_tpm_limits" { type = map(number) }
variable "enable_cae_internal_only" { type = bool }
variable "enable_external_ingress" { type = bool }
variable "llm_app" {
  type = object({
    image            = string
    name             = string
    image_repository = string
    image_tag        = string
    target_port      = number
    cpu              = number
    memory           = string
    min_replicas     = number
    max_replicas     = number
    external_ingress = bool
    command          = list(string)
    args             = list(string)
    env              = map(string)
  })
}
variable "test_app" {
  type = object({
    image            = string
    name             = string
    image_repository = string
    image_tag        = string
    cpu              = number
    memory           = string
    min_replicas     = number
    max_replicas     = number
    command          = list(string)
    args             = list(string)
    env              = map(string)
  })
}
variable "val_app" {
  type = object({
    image            = string
    name             = string
    image_repository = string
    image_tag        = string
    cpu              = number
    memory           = string
    min_replicas     = number
    max_replicas     = number
    command          = list(string)
    args             = list(string)
    env              = map(string)
  })
}
variable "tags" { type = map(string) }

resource "azurerm_log_analytics_workspace" "this" {
  name                = "law-${replace(var.container_apps_environment_name, "cae-", "")}-01"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_container_app_environment" "this" {
  name                           = var.container_apps_environment_name
  location                       = var.location
  resource_group_name            = var.resource_group_name
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.this.id
  infrastructure_subnet_id       = var.container_apps_subnet_id
  internal_load_balancer_enabled = var.enable_cae_internal_only
  tags                           = var.tags
}

locals {
  llm_image = trimspace(var.llm_app.image) != "" ? var.llm_app.image : "ghcr.io/berriai/litellm:main-latest"
}

resource "azurerm_container_app" "llm" {
  name                         = var.llm_app.name
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  ingress {
    external_enabled = var.enable_external_ingress
    target_port      = var.llm_app.target_port
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.llm_app.min_replicas
    max_replicas = var.llm_app.max_replicas

    container {
      name   = var.llm_app.name
      image  = local.llm_image
      cpu    = var.llm_app.cpu
      memory = var.llm_app.memory

      env {
        name  = "LITELLM_MODE"
        value = "azure"
      }
    }
  }

  tags = var.tags
}

output "container_app_environment_id" { value = azurerm_container_app_environment.this.id }
output "container_app_id" { value = azurerm_container_app.llm.id }
output "container_app_name" { value = azurerm_container_app.llm.name }
output "container_app_latest_revision_fqdn" { value = azurerm_container_app.llm.latest_revision_fqdn }
output "container_app_ids" { value = { llm = azurerm_container_app.llm.id, test = null, val = null } }
output "container_app_names" { value = { llm = azurerm_container_app.llm.name, test = null, val = null } }
output "container_app_latest_revision_fqdns" { value = { llm = azurerm_container_app.llm.latest_revision_fqdn, test = null, val = null } }
output "log_analytics_workspace_id" { value = azurerm_log_analytics_workspace.this.id }
output "application_insights_id" { value = null }

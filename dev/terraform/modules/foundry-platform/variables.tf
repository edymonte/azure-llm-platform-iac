# ────────────────────────────────────────────────────────────────────────────────
# FOUNDRY PLATFORM — MODULE VARIABLES
# ────────────────────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Project short name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, hml, prod)"
  type        = string
}

variable "primary_location" {
  description = "Primary region for global resources"
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group name"
  type        = string
}

variable "regions" {
  description = "Foundry deployment regions"
  type = map(object({
    location      = string
    location_code = string
    enabled       = bool
    capacity      = optional(number)
  }))
}

variable "foundry_models_config" {
  description = "Model deployment configuration"
  type = object({
    deployment_name = string
    model_name      = string
    model_format    = string
    model_version   = string
    sku_name        = string
    capacity        = number
  })
}

variable "vnet_address_space" {
  type = list(string)
}

variable "workload_subnet_prefix" {
  type = string
}

variable "private_endpoint_subnet_prefix" {
  type = string
}

variable "ai_services_subnet_prefix" {
  type = string
}

variable "container_apps_subnet_prefix" {
  type = string
}

variable "quota_limits" {
  description = "Model deployment capacity"
  type = object({
    gpt_4o_quota = number
  })
}

variable "key_vault_name" {
  type = string
}

variable "key_vault_sku" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "resolve_latest_model_version" {
  type    = bool
  default = true
}

variable "enable_soft_deleted_account_purge" {
  type    = bool
  default = true
}

variable "container_apps_config" {
  type = object({
    enabled             = bool
    container_env_name  = string
    acr_login_server    = string
    acr_resource_id     = string
    litellm_config_yaml = string
    llm_app = object({
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
    test_app = object({
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
    val_app = object({
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
  })
}

variable "litellm_tpm_limits" {
  type    = map(number)
  default = {}
}

variable "enable_cae_internal_only" {
  type    = bool
  default = true
}

variable "allowed_test_cidrs" {
  type    = list(string)
  default = []
}

variable "enable_litellm_external_ingress" {
  type    = bool
  default = false
}

variable "prisma_cloud_cidrs" {
  type    = list(string)
  default = []
}

variable "enable_public_network_access" {
  type    = bool
  default = true
}

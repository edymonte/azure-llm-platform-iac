# ────────────────────────────────────────────────────────────────────────────────
# AZURE LLM PLATFORM — VARIABLES
# Azure AI Foundry with GPT-4o Multi-Region
# ────────────────────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Short project name used in resource naming"
  type        = string
  default     = "azllm"
}

variable "environment" {
  description = "Environment (dev, hml, prod)"
  type        = string
  default     = "dev"
}

variable "primary_location" {
  description = "Primary region for the central Resource Group"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Centralized Resource Group name"
  type        = string
  default     = "rg-azllm-foundry-dev"
}

# ────────────────────────────────────────────────────────────────────────────────
# REGIONS
# ────────────────────────────────────────────────────────────────────────────────
variable "regions" {
  description = "Azure regions for AI Foundry deployment"
  type = map(object({
    location      = string
    location_code = string
    enabled       = bool
    # Cota de tokens por minuto (TPM) em unidades de 1000 para esta região.
    # Sobrescreve foundry_models_config.capacity quando definido.
    # Ex: 150 = 150.000 TPM (GlobalStandard gpt-4o)
    capacity      = optional(number)
  }))

  default = {
    eastus = {
      location      = "East US"
      location_code = "eus"
      enabled       = true
      capacity      = 150
    }
    westus3 = {
      location      = "West US 3"
      location_code = "wus3"
      enabled       = true
      capacity      = 150
    }
  }
}

# ────────────────────────────────────────────────────────────────────────────────
# LLM MODEL CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────
variable "foundry_models_config" {
  description = "Model deployment config for Global Standard SKU"
  type = object({
    deployment_name = string
    model_name      = string
    model_format    = string
    model_version   = string
    sku_name        = string
    capacity        = number
  })

  default = {
    deployment_name = "gpt-4o"
    model_name      = "gpt-4o"
    model_format    = "OpenAI"
    model_version   = "2024-11-20"
    sku_name        = "GlobalStandard"
    capacity        = 150
  }
}

variable "litellm_tpm_limits" {
  description = "TPM limits per region for LiteLLM usage-based routing"
  type        = map(number)
  default = {
    eastus  = 150000
    westus3 = 150000
  }
}

# ────────────────────────────────────────────────────────────────────────────────
# NETWORKING
# ────────────────────────────────────────────────────────────────────────────────
variable "vnet_address_space" {
  description = "VNet address space"
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "workload_subnet_prefix" {
  description = "Subnet for general workloads"
  type        = string
  default     = "10.20.0.0/23"
}

variable "private_endpoint_subnet_prefix" {
  description = "Subnet for private endpoints"
  type        = string
  default     = "10.20.2.0/23"
}

variable "ai_services_subnet_prefix" {
  description = "Subnet for AI Services"
  type        = string
  default     = "10.20.4.0/23"
}

variable "container_apps_subnet_prefix" {
  description = "Subnet for Azure Container Apps Environment"
  type        = string
  default     = "10.20.6.0/23"
}

variable "enable_cae_internal_only" {
  description = "Container Apps Environment internal-only (true = VNet-only; false = public). In staging/prod always true."
  type        = bool
  default     = true
}

variable "allowed_test_cidrs" {
  description = "CIDRs allowed in NSG when CAE is public (e.g. dev machine IP). Empty = block all."
  type        = list(string)
  default     = []
}

variable "enable_litellm_external_ingress" {
  description = "Enable external ingress on LiteLLM container app (true only for dev testing)"
  type        = bool
  default     = false
}

variable "prisma_cloud_cidrs" {
  description = "Security scanner IPs allowed on Storage Account firewall"
  type        = list(string)
  default     = []
}

variable "enable_public_network_access" {
  description = "Whether to enable public network access on Foundry accounts and Storage Account"
  type        = bool
  default     = true
}

# ────────────────────────────────────────────────────────────────────────────────
# QUOTA LIMITS
# ────────────────────────────────────────────────────────────────────────────────
variable "quota_limits" {
  description = "Deployment capacity for GPT-4o"
  type = object({
    gpt_4o_quota = number
  })

  default = {
    gpt_4o_quota = 150
  }
}

# ────────────────────────────────────────────────────────────────────────────────
# KEY VAULT
# ────────────────────────────────────────────────────────────────────────────────
variable "key_vault_name" {
  description = "Key Vault name (must be globally unique)"
  type        = string
  default     = "kv-azllm-fnd-dev"
}

variable "key_vault_sku" {
  description = "Key Vault SKU (standard or premium)"
  type        = string
  default     = "standard"
}

# ────────────────────────────────────────────────────────────────────────────────
# WINDOWS COMPATIBILITY
# ────────────────────────────────────────────────────────────────────────────────
variable "resolve_latest_model_version" {
  description = "Resolve latest model version from Azure catalog before provisioning"
  type        = bool
  default     = true
}

variable "enable_soft_deleted_account_purge" {
  description = "Purge soft-deleted Cognitive Services accounts before recreation"
  type        = bool
  default     = true
}

# ────────────────────────────────────────────────────────────────────────────────
# CONTAINER APPS
# ────────────────────────────────────────────────────────────────────────────────
variable "container_apps_config" {
  description = "Azure Container Apps config for LiteLLM proxy, test, and validation apps"
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

  default = {
    enabled             = false
    container_env_name  = ""
    acr_login_server    = ""
    acr_resource_id     = ""
    litellm_config_yaml = ""
    llm_app = {
      image            = ""
      name             = ""
      image_repository = ""
      image_tag        = ""
      target_port      = 4000
      cpu              = 1
      memory           = "2Gi"
      min_replicas     = 0
      max_replicas     = 1
      external_ingress = false
      command          = []
      args             = []
      env              = {}
    }
    test_app = {
      image            = ""
      name             = ""
      image_repository = ""
      image_tag        = ""
      cpu              = 0.5
      memory           = "1Gi"
      min_replicas     = 0
      max_replicas     = 1
      command          = []
      args             = []
      env              = {}
    }
    val_app = {
      image            = ""
      name             = ""
      image_repository = ""
      image_tag        = ""
      cpu              = 0.5
      memory           = "1Gi"
      min_replicas     = 0
      max_replicas     = 1
      command          = []
      args             = []
      env              = {}
    }
  }
}

# ────────────────────────────────────────────────────────────────────────────────
# TAGS
# ────────────────────────────────────────────────────────────────────────────────
variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    environment = "dev"
    project     = "azure-llm-platform"
    managed_by  = "terraform"
    workload    = "ai-foundry"
    cost_center = "ai-infrastructure"
  }
}

variable "project_name" {
  description = "Short project name used in resource naming"
  type        = string
  default     = "azllm"
}

variable "environment" {
  description = "Deployment environment (dev, hml, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for backend resources"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Resource Group name for Terraform state"
  type        = string
  default     = "rg-azllm-tfstate-dev"
}

variable "storage_account_name" {
  description = "Globally unique Storage Account name for Terraform state"
  type        = string
  default     = "stazllmtfdev"
}

variable "blob_container_name" {
  description = "Blob container name for state files"
  type        = string
  default     = "tfstate"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    environment = "dev"
    project     = "azure-llm-platform"
    managed_by  = "terraform"
    workload    = "terraform-backend"
  }
}

variable "resource_group_name" {
  description = "Resource Group name (must already exist; pre-provisioned outside Terraform)"
  type        = string
}

variable "location" {
  description = "Azure region (kept for compatibility; ignored when RG already exists)"
  type        = string
}

variable "tags" {
  description = "Tags (kept for compatibility; not applied when RG is pre-existing)"
  type        = map(string)
}

# RG is pre-created out-of-band because the runner Managed Identity does not have
# subscription-level Contributor. It only has Contributor + User Access Administrator
# scoped to this resource group.
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

output "id" {
  value = data.azurerm_resource_group.main.id
}

output "name" {
  value = data.azurerm_resource_group.main.name
}

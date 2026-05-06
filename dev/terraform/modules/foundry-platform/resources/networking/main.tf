variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "vnet_name" { type = string }
variable "vnet_address_space" { type = list(string) }

variable "workload_subnet" {
  type = object({
    name           = string
    address_prefix = string
  })
}

variable "private_endpoint_subnet" {
  type = object({
    name           = string
    address_prefix = string
  })
}

variable "ai_services_subnet" {
  type = object({
    name           = string
    address_prefix = string
  })
}

variable "container_apps_subnet" {
  type = object({
    name           = string
    address_prefix = string
  })
}

variable "tags" { type = map(string) }

resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet" "workload" {
  name                 = var.workload_subnet.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.workload_subnet.address_prefix]

  service_endpoints = [
    "Microsoft.KeyVault",
    "Microsoft.CognitiveServices",
    "Microsoft.Storage"
  ]
}

resource "azurerm_subnet" "private_endpoint" {
  name                 = var.private_endpoint_subnet.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.private_endpoint_subnet.address_prefix]

  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_subnet" "ai_services" {
  name                 = var.ai_services_subnet.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.ai_services_subnet.address_prefix]

  service_endpoints = ["Microsoft.CognitiveServices"]
}

resource "azurerm_subnet" "container_apps" {
  name                 = var.container_apps_subnet.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.container_apps_subnet.address_prefix]

  delegation {
    name = "aca-delegation"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

output "vnet_id" { value = azurerm_virtual_network.main.id }
output "vnet_name" { value = azurerm_virtual_network.main.name }
output "workload_subnet_id" { value = azurerm_subnet.workload.id }
output "private_endpoint_subnet_id" { value = azurerm_subnet.private_endpoint.id }
output "ai_services_subnet_id" { value = azurerm_subnet.ai_services.id }
output "container_apps_subnet_id" { value = azurerm_subnet.container_apps.id }

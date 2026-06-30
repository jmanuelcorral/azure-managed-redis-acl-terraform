terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.0.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0"
    }
  }
}

provider "azapi" {
  subscription_id = var.subscription_id
}

provider "azurerm" {
  subscription_id     = var.subscription_id
  storage_use_azuread = true
  features {}
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID where resources are created. Set via terraform.tfvars or the TF_VAR_subscription_id / ARM_SUBSCRIPTION_ID environment variable."
}

variable "location" {
  type    = string
  default = "spaincentral"
}

variable "name_prefix" {
  type    = string
  default = "amraclre"
}

# When true, deploys the cluster with public access disabled and reachable only
# through a private endpoint (VNet + subnet + private DNS zone created below).
variable "enable_private_networking" {
  type    = bool
  default = true
}

# Optional extra Entra principal (e.g. an app's managed identity / service principal
# objectId) to receive its own ACL assignment, demonstrating multiple assignments.
variable "extra_principal_object_id" {
  type    = string
  default = ""
}

# Current Entra identity — assigned to the Redis default access policy (ACL preview)
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "rg-amr-aclpreview"
  location = var.location
}

# --- Private networking (only created when enable_private_networking = true) ---
resource "azurerm_virtual_network" "vnet" {
  count               = var.enable_private_networking ? 1 : 0
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.42.0.0/16"]
}

resource "azurerm_subnet" "pe" {
  count                = var.enable_private_networking ? 1 : 0
  name                 = "snet-pe"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet[0].name
  address_prefixes     = ["10.42.1.0/24"]
}

# Azure Managed Redis private DNS zone.
resource "azurerm_private_dns_zone" "redis" {
  count               = var.enable_private_networking ? 1 : 0
  name                = "privatelink.redis.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  count                 = var.enable_private_networking ? 1 : 0
  name                  = "redis-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.redis[0].name
  virtual_network_id    = azurerm_virtual_network.vnet[0].id
}

module "redis" {
  source            = "../../modules/azure-managed-redis"
  name              = "${var.name_prefix}${substr(md5(azurerm_resource_group.rg.id), 0, 6)}"
  resource_group_id = azurerm_resource_group.rg.id
  location          = var.location
  sku_name          = "Balanced_B0"
  high_availability = false

  # Disable public traffic when private networking is enabled (private endpoint only).
  public_network_access = var.enable_private_networking ? "Disabled" : "Enabled"

  private_endpoint = var.enable_private_networking ? {
    subnet_id            = azurerm_subnet.pe[0].id
    private_dns_zone_ids = [azurerm_private_dns_zone.redis[0].id]
  } : null

  # Multiple ACL assignments: the current identity plus, optionally, an extra principal.
  # Note: the AMR ACL preview only supports the "default" policy today.
  access_policy_assignments = merge(
    {
      "currentuser" = {
        access_policy_name = "default"
        user_object_id     = data.azurerm_client_config.current.object_id
      }
    },
    var.extra_principal_object_id == "" ? {} : {
      "appprincipal" = {
        access_policy_name = "default"
        user_object_id     = var.extra_principal_object_id
      }
    }
  )

  tags = {
    project = "amr-acl-sample"
    purpose = "amr-acl-preview"
  }
}

output "redis_hostname" {
  value = module.redis.hostname
}

output "redis_port" {
  value = module.redis.port
}

output "acl_assignments" {
  value = module.redis.access_policy_assignment_ids
}

output "public_network_access" {
  value = module.redis.public_network_access
}

output "private_endpoint_ip" {
  value = module.redis.private_endpoint_ip
}

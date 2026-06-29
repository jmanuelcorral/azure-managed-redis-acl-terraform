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
  default = "swedencentral"
}

variable "name_prefix" {
  type    = string
  default = "amraclre"
}

# Current Entra identity — assigned to the Redis default access policy (ACL preview)
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "rg-amr-aclpreview"
  location = "westeurope"
}

module "redis" {
  source            = "../../modules/azure-managed-redis"
  name              = "${var.name_prefix}${substr(md5(azurerm_resource_group.rg.id), 0, 6)}"
  resource_group_id = azurerm_resource_group.rg.id
  location          = var.location
  sku_name          = "Balanced_B0"
  high_availability = false

  access_policy_assignments = {
    "currentuser" = {
      access_policy_name = "default"
      user_object_id     = data.azurerm_client_config.current.object_id
    }
  }

  tags = {
    project = "mutuasampleaclrme"
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

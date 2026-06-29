# Azure Managed Redis cluster
resource "azapi_resource" "cluster" {
  type      = "Microsoft.Cache/redisEnterprise@2025-07-01"
  name      = var.name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  body = {
    sku = {
      name = var.sku_name
    }
    properties = {
      highAvailability    = var.high_availability ? "Enabled" : "Disabled"
      publicNetworkAccess = "Enabled"
    }
  }

  response_export_values = ["properties.hostName"]
}

# Default database for the Managed Redis cluster
resource "azapi_resource" "database" {
  type      = "Microsoft.Cache/redisEnterprise/databases@2025-07-01"
  name      = "default"
  parent_id = azapi_resource.cluster.id

  body = {
    properties = {
      clientProtocol           = var.client_protocol
      port                     = 10000
      clusteringPolicy         = "OSSCluster"
      evictionPolicy           = "NoEviction"
      accessKeysAuthentication = var.access_keys_authentication ? "Enabled" : "Disabled"
    }
  }

  response_export_values = ["properties.port"]
}

# ACL data-access policy assignment (Public Preview) — binds an Entra principal to the access policy
resource "azapi_resource" "access_policy_assignment" {
  for_each  = var.access_policy_assignments
  type      = "Microsoft.Cache/redisEnterprise/databases/accessPolicyAssignments@2025-08-01-preview"
  name      = each.key
  parent_id = azapi_resource.database.id

  body = {
    properties = {
      accessPolicyName = each.value.access_policy_name
      user = {
        objectId = each.value.user_object_id
      }
    }
  }
}

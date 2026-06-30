output "cluster_id" {
  value       = azapi_resource.cluster.id
  description = "Resource ID of the Managed Redis cluster."
}

output "hostname" {
  value       = try(azapi_resource.cluster.output.properties.hostName, null)
  description = "Cluster hostname."
}

output "port" {
  value       = try(azapi_resource.database.output.properties.port, 10000)
  description = "Redis port."
}

output "access_policy_assignment_ids" {
  value       = { for k, v in azapi_resource.access_policy_assignment : k => v.id }
  description = "IDs of the ACL access policy assignments."
}

output "public_network_access" {
  value       = var.public_network_access
  description = "Public network access state of the cluster (Enabled/Disabled)."
}

output "private_endpoint_id" {
  value       = var.private_endpoint == null ? null : azurerm_private_endpoint.this[0].id
  description = "Resource ID of the private endpoint (null if not created)."
}

output "private_endpoint_ip" {
  value       = var.private_endpoint == null ? null : try(azurerm_private_endpoint.this[0].private_service_connection[0].private_ip_address, null)
  description = "Private IP address assigned to the private endpoint (null if not created)."
}

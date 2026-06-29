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

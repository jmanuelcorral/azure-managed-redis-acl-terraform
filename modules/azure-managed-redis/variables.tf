variable "name" {
  type        = string
  description = "Name of the Azure Managed Redis cluster."
}

variable "resource_group_id" {
  type        = string
  description = "Resource ID of the resource group where the cluster is created."
}

variable "location" {
  type        = string
  default     = "westeurope"
  description = "Azure region."
}

variable "sku_name" {
  type        = string
  default     = "Balanced_B0"
  description = "Azure Managed Redis SKU (e.g. Balanced_B0, MemoryOptimized_M10, ComputeOptimized_X5)."
}

variable "high_availability" {
  type        = bool
  default     = true
  description = "Enable high availability."
}

variable "client_protocol" {
  type        = string
  default     = "Encrypted"
  description = "Client connection protocol: Encrypted (TLS) or Plaintext."
}

variable "public_network_access" {
  type        = string
  default     = "Enabled"
  description = "Public network access to the cluster: 'Enabled' or 'Disabled'. Set to 'Disabled' when connecting exclusively through private endpoints."

  validation {
    condition     = contains(["Enabled", "Disabled"], var.public_network_access)
    error_message = "public_network_access must be either 'Enabled' or 'Disabled'."
  }
}

variable "access_keys_authentication" {
  type        = bool
  default     = false
  description = "Allow access-key authentication. Disabled to enforce Microsoft Entra ID auth."
}

variable "access_policy_assignments" {
  type = map(object({
    access_policy_name = optional(string, "default")
    user_object_id     = string
  }))
  default     = {}
  description = <<-EOT
    ACL data-access policy assignments (Public Preview). Map of assignment name -> object.

    You can create MULTIPLE assignments (one per map entry), each binding a different
    Microsoft Entra principal (user, group, managed identity or service principal) by
    its objectId.

    NOTE on granularity: the AMR ACL preview API (2025-08-01-preview) currently only
    supports the built-in "default" data-access policy (full data-plane access).
    Custom granular policies (e.g. read-only) are not yet available, so `access_policy_name`
    must remain "default" for now. The field is kept parametrizable so additional
    policies can be used without code changes once Azure expands the preview.

    The assignment name (map key) must be alphanumeric: ^[A-Za-z0-9]{1,60}$.
  EOT

  validation {
    condition     = alltrue([for v in values(var.access_policy_assignments) : v.access_policy_name == "default"])
    error_message = "The AMR ACL preview only supports access_policy_name = \"default\". Update this validation once Azure adds more built-in policies."
  }
}

variable "private_endpoint" {
  type = object({
    subnet_id            = string
    name                 = optional(string)
    private_dns_zone_ids = optional(list(string), [])
  })
  default     = null
  description = <<-EOT
    Optional private endpoint for the cluster. When set, a private endpoint is created
    against the cluster (subresource/groupId "redisEnterprise").

    - subnet_id: subnet where the private endpoint NIC is placed.
    - name: optional private endpoint name (defaults to "<cluster>-pe").
    - private_dns_zone_ids: optional list of Private DNS zone IDs to wire a
      private_dns_zone_group. For Azure Managed Redis use the zone
      "privatelink.redis.azure.net".

    Typically combined with public_network_access = "Disabled".
  EOT
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags."
}

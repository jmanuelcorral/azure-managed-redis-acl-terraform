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
  description = "ACL data-access policy assignments (Public Preview). Map of name -> Entra object ID."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags."
}

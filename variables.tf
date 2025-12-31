# Variables for Azure Resource Lock Governance

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "resource-lock-governance"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "lock_level" {
  description = "Level of the management lock (CanNotDelete or ReadOnly)"
  type        = string
  default     = "CanNotDelete"

  validation {
    condition     = contains(["CanNotDelete", "ReadOnly"], var.lock_level)
    error_message = "Lock level must be CanNotDelete or ReadOnly."
  }
}

variable "enable_policy" {
  description = "Enable automatic policy enforcement for resource locks"
  type        = bool
  default     = true
}

variable "exempt_resource_groups" {
  description = "List of resource group names exempt from lock policy"
  type        = list(string)
  default     = []
}

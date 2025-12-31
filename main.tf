# Azure Resource Lock Governance
# Automated resource protection using Azure Resource Locks with Policy

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Data Sources
data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

# Resource Group for governance resources
resource "azurerm_resource_group" "governance" {
  name     = "${var.project_name}-rg"
  location = var.location

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "Resource Lock Governance"
  }
}

# Custom Policy Definition - Apply lock when Protected tag is true
resource "azurerm_policy_definition" "lock_protected_resources" {
  name         = "apply-lock-to-protected-resources"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Apply CanNotDelete lock to protected resources"
  description  = "Automatically applies a CanNotDelete lock to resources tagged with Protected=true"

  metadata = jsonencode({
    category = "Security"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "tags['Protected']"
          equals = "true"
        },
        {
          field  = "type"
          equals = "Microsoft.Resources/subscriptions/resourceGroups"
        }
      ]
    }
    then = {
      effect = "deployIfNotExists"
      details = {
        type = "Microsoft.Authorization/locks"
        existenceCondition = {
          field  = "Microsoft.Authorization/locks/level"
          equals = var.lock_level
        }
        roleDefinitionIds = [
          "/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
        ]
        deployment = {
          properties = {
            mode = "incremental"
            template = {
              "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
              contentVersion = "1.0.0.0"
              resources = [
                {
                  type       = "Microsoft.Authorization/locks"
                  apiVersion = "2020-05-01"
                  name       = "ProtectedResourceLock"
                  properties = {
                    level = var.lock_level
                    notes = "Applied automatically by Azure Policy for protected resources"
                  }
                }
              ]
            }
          }
        }
      }
    }
  })
}

# Policy Assignment at Subscription Level
resource "azurerm_subscription_policy_assignment" "lock_protected_resources" {
  count                = var.enable_policy ? 1 : 0
  name                 = "apply-resource-locks"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_definition.lock_protected_resources.id
  description          = "Automatically applies CanNotDelete locks to resources tagged with Protected=true"
  display_name         = "Apply Resource Locks to Protected Resources"

  location = var.location

  identity {
    type = "SystemAssigned"
  }
}

# Grant the policy's managed identity Owner role to apply locks
resource "azurerm_role_assignment" "policy_lock_contributor" {
  count                = var.enable_policy ? 1 : 0
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Owner"
  principal_id         = azurerm_subscription_policy_assignment.lock_protected_resources[0].identity[0].principal_id
}

# Demo: Protected Resource Group
resource "azurerm_resource_group" "protected_demo" {
  name     = "${var.project_name}-protected-demo-rg"
  location = var.location

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Protected   = "true"  # This triggers the policy
  }
}

# Direct Management Lock on demo resource group (immediate protection)
resource "azurerm_management_lock" "protected_demo" {
  name       = "CanNotDelete-Lock"
  scope      = azurerm_resource_group.protected_demo.id
  lock_level = var.lock_level
  notes      = "Protected resource - deletion requires lock removal first"
}

# Demo: Storage Account in protected resource group
resource "azurerm_storage_account" "protected_demo" {
  name                     = replace("${var.project_name}demosa", "-", "")
  resource_group_name      = azurerm_resource_group.protected_demo.name
  location                 = azurerm_resource_group.protected_demo.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # Security best practices
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Protected   = "true"
  }
}

# Lock on the storage account itself
resource "azurerm_management_lock" "storage_account" {
  name       = "CanNotDelete-StorageAccount"
  scope      = azurerm_storage_account.protected_demo.id
  lock_level = var.lock_level
  notes      = "Protected storage account - contains critical data"
}

# Log Analytics Workspace for monitoring lock operations
resource "azurerm_log_analytics_workspace" "governance" {
  name                = "${var.project_name}-law"
  location            = azurerm_resource_group.governance.location
  resource_group_name = azurerm_resource_group.governance.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Activity Log export for audit trail
resource "azurerm_monitor_diagnostic_setting" "subscription_activity" {
  name                       = "${var.project_name}-activity-logs"
  target_resource_id         = data.azurerm_subscription.current.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.governance.id

  enabled_log {
    category = "Administrative"
  }

  enabled_log {
    category = "Security"
  }

  enabled_log {
    category = "Policy"
  }
}

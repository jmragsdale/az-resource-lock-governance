# Outputs for Azure Resource Lock Governance

output "policy_definition_id" {
  description = "ID of the custom policy definition"
  value       = azurerm_policy_definition.lock_protected_resources.id
}

output "policy_assignment_id" {
  description = "ID of the policy assignment"
  value       = var.enable_policy ? azurerm_subscription_policy_assignment.lock_protected_resources[0].id : null
}

output "demo_resource_group_id" {
  description = "ID of the demo protected resource group"
  value       = azurerm_resource_group.protected_demo.id
}

output "demo_resource_group_name" {
  description = "Name of the demo protected resource group"
  value       = azurerm_resource_group.protected_demo.name
}

output "lock_id" {
  description = "ID of the management lock on the demo resource group"
  value       = azurerm_management_lock.protected_demo.id
}

output "storage_account_id" {
  description = "ID of the protected storage account"
  value       = azurerm_storage_account.protected_demo.id
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace for audit logs"
  value       = azurerm_log_analytics_workspace.governance.id
}

output "verify_lock_command" {
  description = "Azure CLI command to verify locks are applied"
  value       = "az lock list --resource-group ${azurerm_resource_group.protected_demo.name}"
}

output "test_deletion_command" {
  description = "Azure CLI command to test deletion protection (will fail)"
  value       = "az group delete --name ${azurerm_resource_group.protected_demo.name} --yes"
}

output "remove_lock_command" {
  description = "Azure CLI command to remove lock (for authorized changes)"
  value       = "az lock delete --name CanNotDelete-Lock --resource-group ${azurerm_resource_group.protected_demo.name}"
}

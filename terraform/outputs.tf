output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "subnet_ids" {
  description = "IDs of the created subnets"
  value       = module.network.subnet_ids
}

output "vnet_name" {
  description = "Name of the created vnet"
  value       = module.network.vnet_name
}
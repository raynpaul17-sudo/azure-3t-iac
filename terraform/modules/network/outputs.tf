output "subnet_ids" {
  description = "IDs of the created subnets, keyed by tier name"
  value       = { for name, subnet in azurerm_subnet.main : name => subnet.id }
}

output "nsg_ids" {
  description = "IDs of the created network security group, keyed by tier name"
  value       = { for name, nsg in azurerm_network_security_group.main : name => nsg.id }
}

output "vnet_id" {
  description = "ID of the created vnet"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the created vnet"
  value       = azurerm_virtual_network.main.name
}
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

output "lb_public_ip" {
  description = "Public IP of the load balancer"
  value       = module.loadbalancer.public_ip_address
}

output "vm_private_ips" {
  description = "Private IP addresses of the VMs, keyed by tier name"
  value       = module.compute.private_ips

}

output "ssh_frontend_port" {
  description = "Public port forwarded to SSH on the front VM"
  value       = var.ssh_frontend_port
}

output "adminusername" {
  description = "Administrator username created on every VM"
  value       = var.admin_username
}

output "subnet_address_prefixes" {
  description = "Address prefix of each subnet, keyed by tier name"
  value       = { for name, subnet in var.subnets : name => subnet.address_prefix }
}

output "admin_ip" {
  description = "Public IP allowed to SSH into the front VM"
  value       = var.admin_ip
  sensitive   = true
}

output "keyvault_uri" {
  description = "URI of the key vault"
  value       = module.keyvault.vault_uri
}

output "keyvault_secret_name" {
  description = "Name of the database password secret"
  value       = module.keyvault.secret_name
}

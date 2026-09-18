output "private_ips" {
  description = "Private IP addresses of the VMs, keyed by tier name"
  value       = { for name, nic in azurerm_network_interface.main : name => nic.private_ip_address }
}

output "identity_principal_ids" {
  description = "Principal IDs of the VM system-assigned identities, keyed by tier name"
  value       = { for name, vm in azurerm_linux_virtual_machine.main : name => vm.identity[0].principal_id }
}
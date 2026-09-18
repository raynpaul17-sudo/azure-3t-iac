output "public_ip_address" {
  description = "public Ip of the Load Balancer"
  value       = azurerm_public_ip.main.ip_address
}

output "backend_pool_web_id" {
  description = "id of the web backend_pool"
  value       = azurerm_lb_backend_address_pool.web.id
}

output "backend_pool_outbound_id" {
  description = "id of the outbound backend_pool"
  value       = azurerm_lb_backend_address_pool.outbound.id
}

output "nat_rule_ssh_id" {
  description = "id of the Inbound rule NAT of the Load Balancer"
  value       = azurerm_lb_nat_rule.ssh.id
}
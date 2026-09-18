resource "azurerm_public_ip" "main" {
  name                = "pip-${var.prefix}-lb"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ---------LOAD BALANCER------------------------------

locals {
  frontend_ip_name = "lb-ip-${var.prefix}"
}

resource "azurerm_lb" "main" {
  name                = "lb-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = local.frontend_ip_name
    public_ip_address_id = azurerm_public_ip.main.id
  }
}

resource "azurerm_lb_backend_address_pool" "web" {
  name            = "web-${var.prefix}"
  loadbalancer_id = azurerm_lb.main.id
}

resource "azurerm_lb_backend_address_pool" "outbound" {
  name            = "outbound-${var.prefix}"
  loadbalancer_id = azurerm_lb.main.id
}

resource "azurerm_lb_probe" "main" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "lb-probe-${var.prefix}"
  port            = 80
  protocol        = "Http"
  request_path    = "/"
}

resource "azurerm_lb_rule" "main" {
  for_each                       = var.lb_rules
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "${each.key}-${var.prefix}"
  probe_id                       = azurerm_lb_probe.main.id
  frontend_port                  = each.value.frontend_port
  backend_port                   = each.value.backend_port
  protocol                       = each.value.protocol
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  frontend_ip_configuration_name = local.frontend_ip_name
  disable_outbound_snat          = true
}

resource "azurerm_lb_nat_rule" "ssh" {
  resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "ssh-${var.prefix}"
  protocol                       = "Tcp"
  frontend_port                  = var.ssh_frontend_port
  backend_port                   = 22
  frontend_ip_configuration_name = local.frontend_ip_name
}

resource "azurerm_lb_outbound_rule" "main" {
  name                    = "outbound-${var.prefix}"
  loadbalancer_id         = azurerm_lb.main.id
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.outbound.id
  frontend_ip_configuration {
    name = local.frontend_ip_name
  }
}
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.prefix}"
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "main" {
  for_each                        = var.subnets
  name                            = "snet-${var.prefix}-${each.key}"
  resource_group_name             = var.resource_group_name
  address_prefixes                = [each.value.address_prefix]
  virtual_network_name            = azurerm_virtual_network.main.name
  default_outbound_access_enabled = false
}

resource "azurerm_network_security_group" "main" {
  for_each            = var.subnets
  name                = "nsg-${var.prefix}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet_network_security_group_association" "main" {
  for_each                  = var.subnets
  subnet_id                 = azurerm_subnet.main[each.key].id
  network_security_group_id = azurerm_network_security_group.main[each.key].id
}

resource "azurerm_network_security_rule" "main" {
  for_each                    = var.security_rules
  name                        = each.key
  priority                    = each.value.priority
  direction                   = "Inbound"
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = "*"
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.main[each.value.tier].name
  resource_group_name         = var.resource_group_name
}
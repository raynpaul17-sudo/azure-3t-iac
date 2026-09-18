locals {
  ip_config_name = "ipconfig"
}

resource "azurerm_network_interface" "main" {
  for_each            = var.vms
  name                = "nic-${var.prefix}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = local.ip_config_name
    subnet_id                     = var.subnet_ids[each.key]
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  for_each            = var.vms
  name                = "vm-${var.prefix}-${each.key}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = each.value.size
  network_interface_ids = [
    azurerm_network_interface.main[each.key].id
  ]
  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key_path
  }

  disable_password_authentication = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "outbound" {
  for_each                = var.vms
  network_interface_id    = azurerm_network_interface.main[each.key].id
  ip_configuration_name   = local.ip_config_name
  backend_address_pool_id = var.backend_pool_outbound_id
}

resource "azurerm_network_interface_backend_address_pool_association" "web" {
  network_interface_id    = azurerm_network_interface.main["front"].id
  ip_configuration_name   = local.ip_config_name
  backend_address_pool_id = var.backend_pool_web_id
}

resource "azurerm_network_interface_nat_rule_association" "ssh" {
  network_interface_id  = azurerm_network_interface.main["front"].id
  nat_rule_id           = var.nat_rule_ssh_id
  ip_configuration_name = local.ip_config_name
}
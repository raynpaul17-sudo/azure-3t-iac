resource "azurerm_resource_group" "main" {
  name     = "rg-${var.prefix}"
  location = var.location
}

module "network" {
  source              = "./modules/network"
  prefix              = var.prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  vnet_address_space  = var.vnet_address_space
  subnets             = var.subnets
}
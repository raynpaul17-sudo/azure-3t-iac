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
  security_rules      = local.security_rules
}

module "loadbalancer" {
  source              = "./modules/loadbalancer"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  prefix              = var.prefix
  ssh_frontend_port   = var.ssh_frontend_port
  lb_rules            = var.lb_rules
}

module "compute" {
  source                   = "./modules/compute"
  location                 = var.location
  resource_group_name      = azurerm_resource_group.main.name
  prefix                   = var.prefix
  subnet_ids               = module.network.subnet_ids
  vms                      = var.vms
  admin_username           = var.admin_username
  ssh_public_key           = file(pathexpand(var.ssh_public_key_path))
  backend_pool_outbound_id = module.loadbalancer.backend_pool_outbound_id
  nat_rule_ssh_id          = module.loadbalancer.nat_rule_ssh_id
  backend_pool_web_id      = module.loadbalancer.backend_pool_web_id
}

module "keyvault" {
  source              = "./modules/keyvault"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  prefix              = var.prefix
  admin_ip            = var.admin_ip
  reader_principal_ids = {
    back = module.compute.identity_principal_ids["back"]
    db   = module.compute.identity_principal_ids["db"]
  }
  subnet_ids = [
    module.network.subnet_ids["back"],
    module.network.subnet_ids["db"],
  ]
  secret_name = var.secret_name
}

# ----NSG Security Rules------
locals {
  security_rules = {
    # ---------- front ----------
    front-allow-https-from-internet = {
      tier                   = "front"
      priority               = 100
      access                 = "Allow"
      protocol               = "Tcp"
      source_address_prefix  = "Internet"
      destination_port_range = "443"
    }

    front-allow-http-from-internet = {
      tier                   = "front"
      priority               = 110
      access                 = "Allow"
      protocol               = "Tcp"
      source_address_prefix  = "Internet"
      destination_port_range = "80"
    }

    front-allow-ssh-from-admin = {
      tier                   = "front"
      priority               = 120
      access                 = "Allow"
      protocol               = "Tcp"
      source_address_prefix  = var.admin_ip
      destination_port_range = "22"
    }

    front-allow-probe-from-lb = {
      tier                   = "front"
      priority               = 130
      access                 = "Allow"
      protocol               = "*"
      source_address_prefix  = "AzureLoadBalancer"
      destination_port_range = "*"
    }

    front-deny-vnet-inbound = {
      tier                   = "front"
      priority               = 4000
      access                 = "Deny"
      protocol               = "*"
      source_address_prefix  = "VirtualNetwork"
      destination_port_range = "*"
    }

    # ---------- back ----------
    back-allow-app-from-front = {
      tier                   = "back"
      priority               = 100
      access                 = "Allow"
      protocol               = "Tcp"
      source_address_prefix  = var.subnets["front"].address_prefix
      destination_port_range = "8080"
    }

    back-allow-ssh-from-front = {
      tier                   = "back"
      priority               = 110
      access                 = "Allow"
      protocol               = "Tcp"
      source_address_prefix  = var.subnets["front"].address_prefix
      destination_port_range = "22"
    }

    back-deny-vnet-inbound = {
      tier                   = "back"
      priority               = 4000
      access                 = "Deny"
      protocol               = "*"
      source_address_prefix  = "VirtualNetwork"
      destination_port_range = "*"
    }

    # ---------- db ----------
    db-allow-postgres-from-back = {
      tier                   = "db"
      priority               = 100
      access                 = "Allow"
      protocol               = "Tcp"
      source_address_prefix  = var.subnets["back"].address_prefix
      destination_port_range = "5432"
    }

    db-allow-ssh-from-front = {
      tier                   = "db"
      priority               = 110
      access                 = "Allow"
      protocol               = "Tcp"
      source_address_prefix  = var.subnets["front"].address_prefix
      destination_port_range = "22"
    }

    db-deny-vnet-inbound = {
      tier                   = "db"
      priority               = 4000
      access                 = "Deny"
      protocol               = "*"
      source_address_prefix  = "VirtualNetwork"
      destination_port_range = "*"
    }
  }
}

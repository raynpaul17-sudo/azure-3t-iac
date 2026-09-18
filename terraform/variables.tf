variable "location" {
  description = "Azure region (restricted by Azure for Students policy)"
  type        = string

  validation {
    condition     = contains(["swedencentral", "polandcentral", "norwayeast", "switzerlandnorth", "uaenorth"], var.location)
    error_message = "location must be one of the regions allowed by the subscription policy."
  }
}

variable "prefix" {
  description = "Short prefix used in all resource names (lowercase letters, digits and hyphens)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{2,10}$", var.prefix))
    error_message = "prefix must be 2 to 10 characters: lowercase letters, digits and hyphens."
  }
}

variable "vnet_address_space" {
  description = "Address space of the virtual network"
  type        = list(string)
}

variable "subnets" {
  description = "Subnets to create, keyed by tier name"
  type = map(object({
    address_prefix = string
  }))
}

variable "admin_ip" {
  description = "Public IP allowed to SSH into the front VM, in CIDR notation (e.g. 203.0.113.10/32)"
  type        = string
  validation {
    condition     = can(cidrhost(var.admin_ip, 0))
    error_message = "admin_ip must be a valid CIDR, for example 203.0.113.10/32."
  }
  sensitive = true
}

variable "ssh_frontend_port" {
  description = "Public port forwarded to SSH on the front VM"
  type        = number
}

variable "lb_rules" {
  description = "Load Balancing rules, keyed by rule name"
  type = map(object({
    frontend_port = number
    backend_port  = number
    protocol      = string
  }))
}

variable "vms" {
  description = "Virtual machines to create, keyed by tier name"
  type = map(object({
    size = string
  }))
}

variable "admin_username" {
  description = "Administrator username created on every VM"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Public SSH key content authorized for the admin user"
  type        = string
}
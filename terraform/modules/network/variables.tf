variable "prefix" {
  description = "Short prefix used in all resource names"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the existing resource group to deploy into"
  type        = string
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


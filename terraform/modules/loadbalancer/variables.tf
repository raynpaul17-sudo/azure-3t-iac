variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the existing resource group to deploy into"
  type        = string
}

variable "prefix" {
  description = "Short prefix used in all resource names"
  type        = string
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

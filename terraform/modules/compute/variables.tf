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

variable "subnet_ids" {
  description = "Ids of the created subnets"
  type        = map(string)
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

variable "ssh_public_key" {
  description = "Public SSH key content authorized for the admin user"
  type        = string
}

variable "backend_pool_web_id" {
  description = "ID of the load balancer backend pool receiving web traffic"
  type        = string
}

variable "backend_pool_outbound_id" {
  description = "ID of the load balancer backend pool used for outbound access"
  type        = string
}

variable "nat_rule_ssh_id" {
  description = "ID of the load balancer NAT rule forwarding SSH to the front VM"
  type        = string
}

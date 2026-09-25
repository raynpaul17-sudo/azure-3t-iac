variable "location" {
  description = "Azure region (restricted by Azure for Students policy)"
  type        = string
}

variable "prefix" {
  description = "Short prefix used in all resource names (lowercase letters, digits and hyphens)"
  type        = string
}

variable "admin_ip" {
  description = "Public IP allowed to SSH into the front VM, in CIDR notation (e.g. 203.0.113.10/32)"
  type        = string
  sensitive   = true
}

variable "resource_group_name" {
  description = "Name of the existing resource group to deploy into"
  type        = string
}

variable "reader_principal_ids" {
  description = "Principal IDs of the created VMs keyed by tier name"
  type        = map(string)
}

variable "subnet_ids" {
  description = "IDs of the subnets allowed to reach the key vault"
  type        = list(string)
}

variable "secret_name" {
  description = "Name of the created db secret"
  type        = string
}

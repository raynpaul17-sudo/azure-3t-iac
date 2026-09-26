variable "location" {
  description = "Azure region (restricted by Azure for Students policy)"
  type        = string
  default     = "swedencentral"
}

variable "prefix" {
  description = "Short prefix used in all resource names (lowercase letters, digits and hyphens)"
  type        = string
  default     = "3t-iac-rp"
}

variable "gitlab_project_path" {
  description = "gitlab projecct path used to create the federeated credential"
  type        = string
  default     = "rpaul17/azure-3t-iac"
}

variable "gitlab_ref" {
  description = "Name of the protected branch"
  type        = string
  default     = "main"
}

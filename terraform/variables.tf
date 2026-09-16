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
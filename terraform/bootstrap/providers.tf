provider "azurerm" {
  resource_provider_registrations = "none"
  resource_providers_to_register  = ["Microsoft.ManagedIdentity", "Microsoft.Authorization"]

  features {}
}

# Read current subscription context
data "azurerm_subscription" "current" {}

# Resource group dedicated to bootstrap resources
resource "azurerm_resource_group" "bootstrap" {
  name     = "rg-${var.prefix}-bootstrap"
  location = var.location
}

# User Assigned Managed Identity for CI/CD runners
resource "azurerm_user_assigned_identity" "cicd" {
  name                = "id-${var.prefix}-gitlab-runner"
  resource_group_name = azurerm_resource_group.bootstrap.name
  location            = azurerm_resource_group.bootstrap.location
}

# Federated Identity Credential linking Azure to GitLab OIDC
resource "azurerm_federated_identity_credential" "gitlab" {
  name                      = "fed-${var.prefix}-gitlab"
  user_assigned_identity_id = azurerm_user_assigned_identity.cicd.id

  # Issuer URL for GitLab SaaS
  issuer   = "https://gitlab.com"
  audience = ["api://AzureADTokenExchange"]

  # Restrict access to a specific project branch, environment or tag
  # Format: project_path:<group>/<project>:ref_type:<branch|tag>:ref:<ref_name>
  subject = "project_path:${var.gitlab_project_path}:ref_type:branch:ref:${var.gitlab_ref}"
}

# Assign Reader role at the subscription level
resource "azurerm_role_assignment" "reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.cicd.principal_id
}
